
 $( document ).ready(function() {

    $( '.clickable-list' ).change(function() {
        const rowId = $(this).val();
        const [parentContainer, modelName] = getParentAndModelName(this);
        $.ajax({
            url: `${modelName}/${rowId}`,
            dataType: 'json'
        })
        .done( (msg) => {
            // Only the "series" container has this. If they started
            // creating a new series template but didn't, then we need
            // to turn the button back on.
            parentContainer.find('.select-template-button').prop('disabled', false);
            displayItem(modelName, msg)
        });
    });

    $( '.display-row' ).click(function() {
        const display = $(this).find('.row-contents');
        if (display.is(':hidden')) {
            return;
        }
        display.toggle();
        $(this).find('.row-edit').toggle();
    });

    // because we're handling the submit ourselves with the button
    $( 'form' ).submit(function(e){
        e.preventDefault();
    });

    $( '.save-button' ).click( function() {
        saveAction(this)

        // Only the "series" container has this. If they created a new series
        // template then we can turn the button back on
        const [parentContainer, modelName] = getParentAndModelName(this);
        parentContainer.find('.select-template-button').prop('disabled', false);
    });


    $( '.create-new-button' ).click(function() {

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
        parentContainer.find('.select-template-button').prop('disabled', true);

    });

    /* when they click the line with the '+' on an accordion, toggle the
     * open/close
     */
    $( '.accordion .accordion-label' ).click(function() {
        const [parentContainer, modelName] = getParentAndModelName(this);
        const thisWasActive = parentContainer.hasClass('active');
        $( '.accordion-container' ).removeClass('active');
        if (thisWasActive) {
            return;
        }
        parentContainer.toggleClass('active')
        if (parentContainer.hasClass('active')) {
            loadListForModel(modelName);
        }
    });

    $( '.add-multi-select-button' ).click(multiSelectOptionAdd);

    const labelGetter = row => getLabelForDisplayInItemListbox('band', row);

    bandDialog = $( '#add-band-dialog' ).dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            'Add band to event': () => alert('TODO add a function here'),
            Cancel: function() {
                bandDialog.dialog( "close" );
            }
        },
        close: function() {
            form[ 0 ].reset();
        },
        open: function() {
            $.ajax({
                url: 'bandAll',
                dataType: 'json'
            })
            .done(msg => fillInItemRowList( $('#add-band-dialog .display-row'), msg, [], labelGetter));

            // fill in the form on the dialog with the members of the selected band
            $('select').change(function() {
                const selectedVal = $(this).val();
                $.ajax({
                    url: `band/${selectedVal}`,
                    dataType: 'json'
                })
                .done(msg => {
                    const spanForNames = $('#add-band-dialog .talent-names');
                    spanForNames.text('');
                    const olEl = $(document.createElement('ol'));
                    spanForNames.append(olEl);
                    msg.data.talents.forEach((talent, i) => {
                        const itemEl = document.createElement('li');
                        itemEl.textContent = talent.name;
                        olEl.append(itemEl);
                    });
                });
            });
        }
    });

    form = bandDialog.find( 'form' ).on( 'submit', function( event ) {
        event.preventDefault();
        alert('TODO add the displayed talent to the event as individuals');
    });

    $( '#add-band' ).button().on( 'click', function() {
        bandDialog.dialog( 'open' );
    });

    /*
     * This sets values for this new event to the default values from the series'
     * default event template
     */
    $( '.series-for-event' ).change(function() {
        const [parentContainer, modelName] = getParentAndModelName(this);
        // don't update the defaults when editing an existing event, just for a new one
        if (parentContainer.find('[name="event_id"]').val()) {
            return;
        }
        const seriesId = $(this).val();
        $.ajax({
            url: `series/${seriesId}/template-event`,
            dataType: 'json'
        })
        .done( (msg) => {
            displayItem('event', msg);
            const eventContainer = getContainerForModelName('event');

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

            // this is not a template
            eventContainer.find('[name="is_template"]').attr('0');

        });
    });

    /* This is from the button on the series accordion to popup the default
     * event for the series in a modal.  We copy the container for "event" and
     * re-use it in the popup.
    */
    const eventContainer = getContainerForModelName('event');
    const templateEventPopup = $('#series-template');
    templateEventPopup.attr('title', 'Defaults for new event in this series');
    eventContainer.find('#event-display-form').clone(true).appendTo(templateEventPopup).attr('id', 'template-event-popup');
    templateEventPopup.find('button').remove();
    const seriesSelectboxParent = templateEventPopup.find('select[name="series_id"]').parent();
    templateEventPopup.find('select[name="series_id"]').remove();
    templateEventPopup.attr('modelName', 'event');
    eventTemplateDialog = $( '#series-template' ).dialog({
        autoOpen: false,
        height: 400,
        width: 400,
        modal: true,
        buttons: {
            Save: function() {
                saveAction(
                    templateEventPopup,
                    () => alert(`Template saved for series "${getContainerForModelName('series').find('select option:selected').text()}"`)
                )
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
            const seriesContainer = getContainerForModelName('series');
            const seriesId = seriesContainer.find('[name="series_id"]').val();

            // the series shouldn't be editable in this popup, so...
            // get our seriesId and put it in a hidden input
            const hiddenSeriesIdEl = document.createElement('input');
            hiddenSeriesIdEl.setAttribute('type', 'hidden');
            hiddenSeriesIdEl.setAttribute('name', 'series_id');
            hiddenSeriesIdEl.setAttribute('value', escapeHtml(seriesId));
            seriesSelectboxParent.append(hiddenSeriesIdEl);

            // get the series name and display it
            const seriesName = seriesContainer.find('select option:selected').text();
            const seriesNameEl = document.createTextNode(seriesName);
            seriesSelectboxParent.append(seriesNameEl);

            $.ajax({
                url: `series/${seriesId}/template-event`,
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

    /* this is the button on the series accordion the starts the popup with the
    * series' default event
    */
    $( '.select-template-button' ).click(function() {
        eventTemplateDialog.dialog( 'open' );
    });
});



// ********************************************
// other functions
// ********************************************

/* displayItem
 *
 * They've clicked on an item ("e.g. Berkeley Contra") in the model's (e.g.
 * "Series") select box and we want to show the details for that item.
 */
function displayItem(target, msg) {

    if (msg['error']) {
        alert('error: ' + msg['error']);
    } else {
        let parentContainer, modelName;
        if (typeof target === "string") {
            parentContainer = getContainerForModelName(target);
            modelName = target;
        } else {
            parentContainer = $(target);
            modelName = parentContainer.attr('modelName');
        }
        const targetObj = msg ? msg['data'] : false;
        parentContainer.find('.display-row').each(
            (index, currentRow) => displayItemRow($(currentRow), targetObj)
        );
        // this is the <input type=hidden name=${modelName}_id
        parentContainer.find( `[name="${modelName}_id"]` ).val(targetObj ? targetObj[`${modelName}_id`] : '');
        parentContainer.find('.model-display').show();
    }
}

/* getLabelForDisplayInItemListbox
 *
 * In the data returned from the server for listbox, we usually want to
 * pick the 'name' attribute to display, but in some cases we don't:
 */
const keyToDisplayInItemRow = {
    venue: 'vkey',
    parent_org: 'abbreviation',
};
function getLabelForDisplayInItemListbox (modelName, data) {

    let keyname;
    if (keyName = keyToDisplayInItemRow[modelName]) {
        return data[keyName];
    } else {
        return data['name'];
    }
}

/* displayItemRow
 *
 * The "item" is the thing we're displaying, like an event or a venue. This
 * "currentRow" is one thing for that, like "long_desc" or a listbox like
 * "style" or "venue".
 */
function displayItemRow(currentRow, targetObj) {

    currentRow.children('.row-contents').show();
    currentRow.children('.row-edit').hide();
    switch(currentRow.attr('column-type')) {
        case 'text-item':
            const theText = targetObj
                ? targetObj[currentRow.attr('name')]
                : '';
            let displayText = escapeHtml(theText);
            displayText = displayText.replace(/\n/g, '<br/>');
            currentRow.children('.row-contents').html(displayText);
            currentRow.children('.row-edit').val(theText);
            break;
        case 'hidden-item':
            const theValue = targetObj
                ? targetObj[currentRow.attr('name')]
                : '';
            currentRow.children('.row-edit').val(theValue);
            break;
        case 'list-item':
            const modelName = currentRow.attr('model-name');
            const tableName = currentRow.attr('table-name');
            const selections = targetObj
                ? targetObj[tableName]
                : '';
            const labelGetter = row => getLabelForDisplayInItemListbox(modelName, row);
            $.ajax({
                url: `${modelName}All`,
                dataType: 'json'
            })
            .done((msg) => fillInItemRowList(currentRow, msg, selections, labelGetter));

            break;
        default:
            console.log(`displayItemRow's currentRow `, currentRow, `'s currentRow.attr('column-type') is ${currentRow.attr('column-type')}`);
    }
}


/* fillInItemRowList
 *
 * We're displaying an "item", like an event, going through each of its "rows"
 * on the display, and we've hit one that's a listbox.
 */
function fillInItemRowList(currentRow, msg, selections, labelGetter) {
    if (msg['data']) {
        const rows = msg['data'];
        const name = currentRow.attr('name');
        const insertTarget = currentRow.find('select');
        insertTarget.find('option').remove();
        currentRow.find('[cloned-selectlist=1]').remove();
        rows.forEach((row, i) => {
            const element = document.createElement('option');
            const label = labelGetter(row);
            element.innerHTML = escapeHtml(label);
            element.setAttribute('value', escapeHtml(row[name]));
            insertTarget.append(element);
        });
        if (selections && selections.length) {
            insertTarget.val(selections[0]['id']);
            for (var i = 1; i < selections.length; i++) {
                //const clone = insertTarget.clone();
                const clone = multiSelectOptionAdd.call(insertTarget);
                clone.val(selections[i]['id']);
            }
        } else {
            insertTarget.val('');
        }
    } else {
        alert('error: ' + msg['error']);
    }
}

/* displayListForModel
 *
 * This is the main chooser list for a given model, like "Events" or "Venues".
 */
function displayListForModel(modelName, msg) {

    const insertTarget = getContainerForModelName(modelName).find('.clickable-list');

    if (msg['data']) {

        const rows = msg['data'];

        rows.forEach((row, i) => {
            const element = document.createElement('option');
            const label = getLabelForDisplayInItemListbox(modelName, row);
            element.innerHTML = escapeHtml(label);
            element.setAttribute('value', escapeHtml(row[`${modelName}_id`]));
            insertTarget.append(element);
        });
    } else {
        alert('fail: ' + msg['error']);
    }
}

function loadListForModel(modelName) {

    const urlForModel = {
        'event': 'eventsUpcoming',
    };
    const url = urlForModel[modelName] || `${modelName}All`;

    getContainerForModelName(modelName).find('.clickable-list' ).empty();
    $( `#${modelName}-display` ).first().hide();

    $.ajax({
        url: url,
        dataType: 'json'
    })
    .done( (msg) => { displayListForModel(modelName, msg) });
}

function escapeHtml(unsafe) {
    unsafe = new String(unsafe); // is that right? else "unsafe.replace is not a function"
    return unsafe
         .replace(/&/g, '&amp;')
         .replace(/</g, '&lt;')
         .replace(/>/g, '&gt;')
         .replace(/'/g, '&quot;')
         .replace(/'/g, '&#039;');
}

function getParentAndModelName(element) {
    const parentContainer = $(element).closest('[modelName]');
    const modelName = parentContainer.attr('modelName');
    return [parentContainer, modelName];
}
function getContainerForModelName(modelName) {
    return $( `.accordion-container[modelName="${modelName}"]` );
}

function multiSelectOptionAdd() {
    const displayRow = $(this).closest('.display-row')
    const newSelectBoxDiv = displayRow.find('.multi-select-wrapper:first').clone();
    displayRow.append(newSelectBoxDiv);
    const newSelectBox = newSelectBoxDiv.find('select').first();
    newSelectBox.val('');
    newSelectBoxDiv.append('<span class="remove-multi-select-button">x</span>');
    newSelectBoxDiv.find('.remove-multi-select-button' ).click(function() {
        $(this).closest('.multi-select-wrapper').remove();
    });
    newSelectBoxDiv.attr('cloned-selectlist', 1);
    return newSelectBox;
}


/* saveAction
 * action for the "Save" button on any of the forms
 */
function saveAction(target, onSuccess) {

    const [parentContainer, modelName] = getParentAndModelName(target);

    const rowId = parentContainer.find(`[name="${modelName}_id"]` ).val();
    const dataString = parentContainer.find( '.display-form' ).serialize();

    let http_method;
    let url;
    if (rowId) {
        http_method = 'put';
        url = `${modelName}/${rowId}`
    } else {
        http_method = 'post';
        url = `${modelName}/`;
    }
    $.ajax({
        url,
        dataType: 'json',
        method: http_method,
        data: dataString
    })
    .done( (msg) => {
        loadListForModel(modelName);
        displayItem(modelName, msg);
        if (onSuccess) {
            onSuccess();
        }
     })
    .fail( () => { alert('something bad happened, update failed') }); // FIXME later
}
