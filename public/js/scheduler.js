import * as h from "./event-handlers.js";
import {
    getParentAndModelName,
    getParentContainerForModelName,
    displayItem,
    loadListForModel,
    multiSelectOptionAdd,
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
     * default event template
     */
    $( '.series-for-event' ).change( h.seriesForEventOnchange );

    $( '#template-help' ).click(function() {
        templateHelpDialog.dialog( 'open' );
    });
    $( '#manage-template-help' ).click(function() {
        templateHelpDialog.dialog( 'open' );
    });

    /* this is the button on the series accordion the starts the popup with the
    * series' default event
    */
    $( '.select-template-button' ).click(function() {
        eventTemplateDialog.dialog( 'open' );
    });

    // make our fancy slide switches actually function
    $('.custom-bool').click( h.customBoolOnclick ); 

    /* This is from the button on the series accordion to popup the default
     * event for the series in a modal.  We copy the container for "event" and
     * re-use it in the popup.
    */
    const eventContainer = getParentContainerForModelName('event');
    const templateEventPopup = $('#series-template');

    templateEventPopup.attr('title', 'Defaults for new event in this series');

    const eventDisplayForm = eventContainer.find('#event-display-form').first();
    const popupForm = eventDisplayForm.clone(true);
    popupForm[0].saveHelper = eventDisplayForm[0].saveHelper;
    popupForm.appendTo(templateEventPopup).attr('id', 'template-event-popup');

    templateEventPopup.find('button').remove();

    const seriesSelectboxParent = templateEventPopup
        .find('select[name="series_id"]')
        .parent();

    templateEventPopup.find('select[name="series_id"]').remove();

    templateEventPopup.attr('modelName', 'event');

    const templateHelpDialog = $( '#template-help-modal' ).dialog({
        autoOpen: false,
        height: 400,
        width: 400,
        modal: true,
    });

    const eventTemplateDialog = $( '#series-template' ).dialog({
        autoOpen: false,
        height: 400,
        width: 400,
        modal: true,
        buttons: {
            Save: function() {
                saveAction(templateEventPopup, () => eventTemplateDialog.dialog("close"))
            },
            Cancel: function() {
                eventTemplateDialog.dialog("close");
            },
        },
        close: function() {

            // remove the hidden seriesId input we added in open()
            seriesSelectboxParent.find('input[type="hidden"][name="series_id"]').remove();

            // remove series name label we added in open()
            seriesSelectboxParent.contents().filter(function() {
                return this.nodeType === 3; //Node.TEXT_NODE
            }).remove();

            templateEventPopup.find('form').get(0).reset();
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
                url: `${appUriBase}/series/${seriesId}/template-event`,
                dataType: 'json'
            })
            .done( (msg) => {
                displayItem(templateEventPopup, msg);
            });
        },
    });

    $( '.datepicker' ).datepicker({
          dateFormat: "yy-mm-dd"
    });


    const loginRedirectModal = $( '#login-redirect-modal' ).dialog({
        autoOpen: false,
        height: 400,
        width: 400,
        modal: true,
    });
    const insufficientPermissionsModal = $( '#insufficient-permissions-modal' ).dialog({
        autoOpen: false,
        height: 400,
        width: 400,
        modal: true,
    });




});
