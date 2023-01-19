import * as h from "./event-handlers.js";
import {
    getParentAndModelName,
    getParentContainerForModelName,
    displayItem,
    loadListForModel,
    multiSelectOptionAdd,
    saveAction,
    escapeHtml,
} from "./helper-functions.js";

$( document ).ready(function() {
    $('.remove-multi-select-button' ).click(function() {
        $(this).closest('.multi-select-wrapper').remove();
    });

    // Create empty lists for adding helper functions
    $('.display-form').each(function() {this.saveHelper = []});

    // Load up an item from the list when it's been clicked on
    $( '.clickable-list' ).change( h.clickableListOnchange );

    // Show the editable field when the user clickes the display
    $( '.display-row' ).click( h.displayRowOnclick );

    // because we're handling the submit ourselves with the button
    $( 'form' ).submit(function(e){ e.preventDefault() });

    $( '.save-button' ).click( h.saveButtonOnclick );

    $( '.delete-button' ).click( h.deleteButtonOnclick );

    $( '.cancel-button' ).click( h.cancelButtonOnclick );

    $( '.create-new-button' ).click( h.createNewButtonOnclick );

    /* when they click the line with the '+' on an accordion, toggle the
     * open/close
     */
    $( '.accordion .accordion-label' ).click( h.accordionOnclick );

    $( '.add-multi-select-button' ).click( multiSelectOptionAdd );

    /*
     * This sets values for this new event to the default values from the series'
     * defaults event
     */
    $( '.series-for-event' ).change( h.seriesForEventOnchange );

    $( '#series-defaults-help' ).click(function() {
        seriesDefaultsHelpDialog.dialog( 'open' );
    });
    $( '#manage-defaults-help' ).click(function() {
        seriesDefaultsHelpDialog.dialog( 'open' );
    });

    /* this is the button on the series accordion the starts the popup with the
    * series' default event
    */
    $( '.select-series-defaults-button' ).click(function() {
        seriesDefaultsDialog.dialog( 'open' );
    });

    // make our fancy slide switches actually function
    $('.custom-bool').click( h.customBoolOnclick ); 

    /* This is from the button on the series accordion to popup the default
     * event for the series in a modal.  We copy the container for "event" and
     * re-use it in the popup.
    */
    const eventContainer = getParentContainerForModelName('event');
    const seriesDefaultsPopup = $('#series-defaults-modal');

    seriesDefaultsPopup.attr('title', 'Defaults for new event in this series');

    const eventDisplayForm = eventContainer.find('#event-display-form').first();
    const popupForm = eventDisplayForm.clone(true);
    popupForm[0].saveHelper = eventDisplayForm[0].saveHelper;
    popupForm.appendTo(seriesDefaultsPopup).attr('id', 'series-defaults-popup');

    seriesDefaultsPopup.find('button').remove();

    const seriesSelectboxParent = seriesDefaultsPopup
        .find('select[name="series_id"]')
        .parent();

    seriesDefaultsPopup.find('select[name="series_id"]').remove();

    seriesDefaultsPopup.attr('fold_model', 'event');

    const seriesDefaultsHelpDialog = $( '#series-defaults-help-modal' ).dialog({
        autoOpen: false,
        height: 400,
        width: 400,
        modal: true,
    });

    $('.help-button.v2').each(
        function (){
            const theButton = $(this);
            const newDialog = 
                theButton.find('.help-content').dialog({
                    autoOpen: false,
                    height: 400,
                    width: 400,
                    modal: true,
                });
            theButton.click(function() {
                newDialog.dialog('open');
            });
        }
    );

    const seriesDefaultsDialog = $( '#series-defaults-modal' ).dialog({
        autoOpen: false,
        height: 400,
        width: 400,
        modal: true,
        buttons: {
            Save: function() {
                saveAction(popupForm, () => seriesDefaultsDialog.dialog("close"))
            },
            Cancel: function() {
                seriesDefaultsDialog.dialog("close");
            },
        },
        close: function() {

            // remove the hidden seriesId input we added in open()
            seriesSelectboxParent.find('input[type="hidden"][name="series_id"]').remove();

            // remove series name label we added in open()
            seriesSelectboxParent.contents().filter(function() {
                return this.nodeType === 3; //Node.TEXT_NODE
            }).remove();

            seriesDefaultsPopup.find('form').get(0).reset();
        },
        open: function() {
            const seriesContainer = getParentContainerForModelName('series');
            const seriesId = seriesContainer.find('[name="series_id"]').val();

            // the series shouldn't be editable in this popup, so...
            // get our seriesId and put it in a hidden input
            const hiddenSeriesIdEl = document.createElement('input');
            hiddenSeriesIdEl.setAttribute('type', 'hidden');
            hiddenSeriesIdEl.setAttribute('name', 'series_id');
            hiddenSeriesIdEl.setAttribute('value', escapeHtml(seriesId));
            seriesSelectboxParent.append(hiddenSeriesIdEl);

            // get the series name and display it
            const seriesName = seriesContainer.find('[name="name"] .row-contents').text();
            const seriesNameEl = document.createTextNode(seriesName);
            seriesSelectboxParent.append(seriesNameEl);

            $.ajax({
                url: `${appUriBase}/series/${seriesId}/series-defaults-event`,
                dataType: 'json'
            })
            .done( (msg) => {
                displayItem(seriesDefaultsPopup, msg);
            });
        },
    });

    $( '.datepicker' ).datepicker({
          dateFormat: "yy-mm-dd"
    });
});
