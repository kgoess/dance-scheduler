import {
    multiSelectOptionAdd,
    unpackResults
} from "./helper-functions.js";

$( document ).ready(function() {

    /* This is the code for the modal that pops up when you add a team to an event.
     */
    const teamDialog = $( '#add-team-dialog' ).dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Yes: function() {
                const found = {};
                $( '[fold_model="event"] select[name="style_id"]' ).each(function() {
                    found[$(this).val()] = 1;
                });
                const emptyStyleSelectboxes = $.makeArray($( '#event-display-form [model-name="style"] select' ))
                    .filter(item => !$(item).val()) ;

                teamDialog.styleIds.forEach((incomingStyleId, i) => {
                    if (found[incomingStyleId]) {
                        return;
                    }
                    let firstEmptyStyleSelectbox;
                    if (firstEmptyStyleSelectbox = emptyStyleSelectboxes.shift()) {
                        $(firstEmptyStyleSelectbox).val(incomingStyleId);
                    } else {
                        const lastStyleSelectbox = $( '#event-display-form [model-name="style"] select' ).last();
                        const clone = multiSelectOptionAdd.call(lastStyleSelectbox);
                        clone.val(incomingStyleId);
                    }
                });

                teamDialog.dialog('close');
            },
            No: function() {
                teamDialog.dialog('close');
            }
        },
        open: function() {
            // blank it out to start with otherwise it'll sit there with the
            // last entry
            $('#team-name-in-popup').text('');
            $('#add-team-dialog .style-names').text('loading...');

            $.ajax({
                url: `${appUriBase}/team/${teamDialog.teamId}`,
                dataType: 'json'
            })
            .done(msg => {
                unpackResults(
                    msg,
                    (msg) => {
                        $('#team-name-in-popup').text(msg.data.name);
                        const spanForNames = $('#add-team-dialog .style-names');
                        spanForNames.text('');
                        const olEl = $(document.createElement('ol'));
                        spanForNames.append(olEl);
                        teamDialog.styleIds = [];
                        msg.data.styles.forEach((style, i) => {
                            const itemEl = document.createElement('li');
                            itemEl.textContent = style.name;
                            olEl.append(itemEl);
                            teamDialog.styleIds.push(style.id);
                        });
                    },
                    [msg]
                )
            })
            .fail( (err) => {
                handleError(err);
            });
        },
    });
    $( '[fold_model="event"] select[name="team_id"]' ).change(function() {
        teamDialog.teamId = $(this).val();
        teamDialog.dialog( 'open' );
    });
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
                $( '[fold_model="event"] select[name="talent_id"]' ).each(function() {
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
            // blank it out to start with otherwise it'll sit there with the
            // last entry
            $('#band-name-in-popup').text('');
            $('#add-band-dialog .talent-names').text('loading...');

            $.ajax({
                url: `${appUriBase}/band/${bandDialog.bandId}`,
                dataType: 'json'
            })
            .done(msg => {
                unpackResults(
                    msg,
                    (msg) => {
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
                    },
                    [msg]
                )
            })
            .fail( (err) => {
                handleError(err);
            });
        },
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
