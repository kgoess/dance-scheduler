import {
    multiSelectOptionAdd,
} from "./helper-functions.js";

$( document ).ready(function() {

    /* This is the code for the modal that pops up when you add a band to an event.
     */
    const bandDialog = $( '#add-band-dialog' ).dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Yes: function() {
                const found = {};
                $( 'select[name="talent_id"]' ).each(function() {
                    found[$(this).val()] = 1;
                });
                const emptyTalentSelectboxes = $.makeArray($( '#event-display-form [model-name="talent"] select' ))
                    .filter(item => !$(item).val()) ;

                bandDialog.talentIds.forEach((incomingTalentId, i) => {
                    if (found[incomingTalentId]) {
                        return;
                    }
                    let firstEmptyTalentSelectbox;
                    if (firstEmptyTalentSelectbox = emptyTalentSelectboxes.shift()) {
                        $(firstEmptyTalentSelectbox).val(incomingTalentId);
                    } else {
                        const lastTalentSelectbox = $( '#event-display-form [model-name="talent"] select' ).last();
                        const clone = multiSelectOptionAdd.call(lastTalentSelectbox);
                        clone.val(incomingTalentId);
                    }
                });

                bandDialog.dialog('close');
            },
            No: function() {
                bandDialog.dialog('close');
            }
        },
        open: function() {
            $.ajax({
                url: `${appUriBase}/band/${bandDialog.bandId}`,
                dataType: 'json'
            })
            .done(msg => {
                $('#band-name-in-popup').text(msg.data.name);
                const spanForNames = $('#add-band-dialog .talent-names');
                spanForNames.text('');
                const olEl = $(document.createElement('ol'));
                spanForNames.append(olEl);
                bandDialog.talentIds = [];
                msg.data.talents.forEach((talent, i) => {
                    const itemEl = document.createElement('li');
                    itemEl.textContent = talent.name;
                    olEl.append(itemEl);
                    bandDialog.talentIds.push(talent.id);
                });
            });
        }
    });
    $( 'select[name="band_id"]' ).change(function() {
        bandDialog.bandId = $(this).val();
        bandDialog.dialog( 'open' );
    });

    /* This helper function will be run by saveAction() before submitting
     */
    $('#event-display-form')[0].saveHelper.push(activeForm => {
        let nameStr = $(activeForm.find('input[name="name"]')).val();
        if (!nameStr){
            const styles = [];
            activeForm.find('select[name="style_id"]').each(function (){
                styles.push(this.options[this.selectedIndex].text);
            });
            const venues = [];
            activeForm.find('select[name="venue_id"]').each(function (){
                venues.push(this.options[this.selectedIndex].text.replace(/ - .*/,''));
            });
            const callers = [];
            activeForm.find('select[name="caller_id"]').each(function (){
                callers.push(this.options[this.selectedIndex].text);
            });
            nameStr = styles.join('/') + ' ' + venues.join('/') + ' ' + callers.join('/');
        };
        $(activeForm.find('input[name="synthetic_name"]')).val(nameStr);
    });

});
