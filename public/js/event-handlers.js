let {
    deleteAction,
    displayItem,
    getLabelForDisplayInItemListbox,
    getParentAndModelName,
    getParentContainerForModelName,
    handleError,
    loadListForModel,
    saveAction,
    unpackResults,
} = await import(`./helper-functions.js?checksum=${jsChecksum}`);


/* listFilterOnchange
 * they type in the box and we filter the selectlist as they type
 */
export function listFilterOnchange() {
    const selectList = $(this).next().find('select');
    const filterText = $(this).val().toLowerCase();
    selectList.children('option').each(function() {
        if ($(this).text().toLowerCase().indexOf(filterText) == -1) {
            $(this).hide();
        } else {
            $(this).show();
        }
    });
}

/* clickableListOnchange
 * When they click on an item in a clickable list, we need to fetch the data
 * for this row and display it.
 */
export function clickableListOnchange() {
    const rowId = $(this).val();
    const [parentContainer, modelName] = getParentAndModelName(this);
    $.ajax({
        url: `${appUriBase}/${modelName}/${rowId}`,
        dataType: 'json'
    })
    .done(msg => {
        unpackResults(
            msg,
            (msg, modelName) => {
                // Only the "series" container has this. If they started
                // creating a new series defaults event but didn't, then we need
                // to turn the button back on.
                parentContainer.find('.select-series-defaults-button').prop('disabled', false);
                displayItem(modelName, msg)
            },
            [msg, modelName]
        )
    })
    .fail( (err) => {
        handleError(err);
    });
}

export function displayRowOnclick() {
    const display = $(this).find('.row-contents');
    if (display.is(':hidden')) {
        return;
    }
    display.toggle();
    $(this).find('.row-edit').toggle().focus();
    $(this).find('.input-disabler').toggle().prop('checked', 'true');
}

export function saveButtonOnclick() {
    saveAction(this)

    // Only the "series" container has this. If they created a new series
    // defaults event then we can turn the button back on
    const [parentContainer, modelName] = getParentAndModelName(this);
    parentContainer.find('.select-series-defaults-button').prop('disabled', false);
}

export function cancelButtonOnclick() {
   const [parentContainer, modelName] = getParentAndModelName(this);
   parentContainer.find('.model-display').hide();
}

export function createNewButtonOnclick() {
    const [parentContainer, modelName] = getParentAndModelName(this);

    displayItem(modelName, false);

    parentContainer.each(
        function(index) {
            $(this).find('.row-contents').hide();
            $(this).find('.row-contents').text('');
            $(this).find('.row-edit').show();
            $(this).find('.row-edit').val('');
        }
    );
    // De-select anything they might have clicked on in the list
    parentContainer.find('select option').prop('selected', false);

    // Only the "series" container has this. we need to turn off the button
    // until they save the new series, otherwise it doesn't make any sense
    parentContainer.find('.select-series-defaults-button').prop('disabled', true);

}

export function accordionOnclick() {
    const [parentContainer, modelName] = getParentAndModelName(this);
    const thisWasActive = parentContainer.hasClass('active');
    // Close all the currently open folds
    $( '.accordion-container' )
        .removeClass('active')
        .find('.model-display').hide();
    // Clear all the search boxes
    $( '.clickable-list-input' ).val('');
    // If the user clicked an active fold, they are just closing it.
    // No need to take further action.
    if (thisWasActive) {
        return;
    }
    // Open the fold they just clicked on.
    parentContainer.toggleClass('active')
    if (parentContainer.hasClass('active')) {
        loadListForModel(modelName);
    }
}

/* seriesForEventOnchange
 *
 * When we're making a new event and they pick a series from the dropdown, this
 * is where we fetch the default values for this event and populate them into
 * the inputs here.
 *
 */
export function seriesForEventOnchange() {
    const [parentContainer, modelName] = getParentAndModelName(this);
    // don't update the defaults when editing an existing event, just for a new one
    if (parentContainer.find('[name="event_id"]').val()) {
        return;
    }
    const seriesId = $(this).val();
    $.ajax({
        url: `${appUriBase}/series/${seriesId}/series-defaults-event`,
        dataType: 'json'
    })
    .done(msg => {
        unpackResults(
            msg,
            afterSeriesForEventOnchangeSuccess,
            [msg]
        )
    })
    .fail( (err) => {
        handleError(err);
    });
}

/*
 * The callback for seriesForEventOnchange's ajax call
 */
function afterSeriesForEventOnchangeSuccess(msg){
    displayItem('event', msg);
    const eventContainer = getParentContainerForModelName('event');

    // keep them from editing an existing event_id, because this is
    // only for *new* events
    eventContainer.find('[name="event_id"]').val('');

    // copying this in from create-new-button, should we re-use it instead?
    eventContainer.each(
        function(index) {
            $(this).find('.row-contents').hide();
            $(this).find('.row-edit').show();
        }
    );

    // this is not a series' defaults
    eventContainer.find('[name="is_series_defaults"]').attr('0');
}

export function customBoolOnclick(){
    const theInput = $(this).find('input');
    if (theInput.val() != "1")
        theInput.val(1);
    else
        theInput.val(0);
}

const deleteConfirmationModal = $( '#delete-confirmation-modal' ).dialog({
    autoOpen: false,
    height: 200,
    width: 400,
    modal: true,
    buttons: {
        Yes: function() {
            deleteAction();
            deleteConfirmationModal.dialog("close");
        },
        No: function() {
            deleteConfirmationModal.dialog("close");
        },
    },
    close: function() {
    },
});
export function deleteButtonOnclick() {
    const [parentContainer, modelName] = getParentAndModelName(this);
    const modal = $( '#delete-confirmation-modal' );
    const fieldName = `${modelName}_id`;

    const idElement = $('#delete-confirmation-modal-id-el');
    idElement.attr('name', fieldName);
    idElement.val(parentContainer.find(`[name="${fieldName}"]`).val());

    modal.find('[name="model-name"]').val(modelName);

    const rowNameCandidate = parentContainer.find('.row-edit[name="name"]').val();


    const theForm = parentContainer.find('.display-form')[0];
    const fd =  new FormData(theForm);
    const formAsObject= Object.fromEntries(fd.entries());

    var rowName= getLabelForDisplayInItemListbox(modelName, formAsObject);
    modal.find('#delete-confirmation-what').text(rowName);

    deleteConfirmationModal.dialog( 'open' );
}
