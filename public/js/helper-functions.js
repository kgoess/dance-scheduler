/* displayItem
 *
 * They've clicked on an item ("e.g. Berkeley Contra") in the model's (e.g.
 * "Series") select box and we want to show the details for that item.
 */
export function displayItem(target, msg) {

    if (msg['error']) {
        alert('error: ' + msg['error']);
    } else {
        let parentContainer, modelName;
        if (typeof target === "string") {
            parentContainer = getParentContainerForModelName(target);
            modelName = target;
        } else {
            parentContainer = $(target);
            modelName = parentContainer.attr('modelName');
        }
        const targetObj = msg ? msg['data'] : false;
        parentContainer.find('.display-row').each(
            (index, currentRow) => displayItemRow($(currentRow), targetObj)
        );
        parentContainer.find('.display-form > input[type="hidden"]').each(
            (index, currentInput) => {
                const theValue = targetObj
                    ? targetObj[currentInput.getAttribute('name')]
                    : '';
                currentInput.value = theValue;
            }
        );
        parentContainer.find('.model-display').show();
    }
}

/* getLabelForDisplayInItemListbox
 *
 * In the data returned from the server for listbox, we usually want to
 * pick the 'name' attribute to display, but in some cases we don't:
 */
const keyToDisplayInItemRow = {
    event: ['start_date', 'synthetic_name'],
    parent_org: 'abbreviation',
    venue: ['vkey', 'hall_name'],
};
export function getLabelForDisplayInItemListbox (modelName, data) {

    let keyname;
    if (keyname = keyToDisplayInItemRow[modelName]) {
        if (Array.isArray(keyname)) {
            return keyname.map(item => data[item]).join(' - ');
        } else {
            return data[keyname];
        }
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
export function displayItemRow(currentRow, targetObj) {
    currentRow.children('.row-contents').show();
    currentRow.children('.row-edit').hide();
    let singleValue = targetObj
        ? targetObj[currentRow.attr('name')]
        : '';
    if (singleValue == null) // to prevent the displayed "null" on unfilled fields.
        singleValue = '';
    switch(currentRow.attr('column-type')) {
        case 'list-item':
            const modelName = currentRow.attr('model-name');
            const tableName = currentRow.attr('table-name');
            const selections = targetObj
                ? targetObj[tableName]
                : '';
            const labelGetter = row => getLabelForDisplayInItemListbox(modelName, row);
            $.ajax({
                url: `${appUriBase}/${modelName}All`,
                dataType: 'json'
            })
            .done((msg) => fillInItemRowList(currentRow, msg, selections, labelGetter));
            break;
        case 'text-item':
            let displayText = escapeHtml(singleValue);
            displayText = displayText.replace(/\n/g, '<br/>');
            currentRow.children('.row-contents').html(displayText);
            currentRow.children('.row-edit').val(singleValue);
            break;
        case 'bool-item':
            currentRow.find('.row-edit input').val(singleValue);
            const divWithAttributes = currentRow.find('.status-switch');
            currentRow.children('.row-contents').html(
                singleValue == "1"
                ? divWithAttributes.attr('data-yes')
                : divWithAttributes.attr('data-no')
                );
            break;
        case 'hidden-item':
            currentRow.children('.row-edit').val(singleValue);
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
export function fillInItemRowList(currentRow, msg, selections, labelGetter) {
    if (msg['data']) {
        const rows = msg['data'];
        const name = currentRow.attr('name');
        const insertTarget = currentRow.find('select');
        insertTarget.find('option').remove();
        currentRow.find('[cloned-selectlist=1]').remove();
        const emptyOption = document.createElement('option');
        emptyOption.innerHTML = '--';
        emptyOption.setAttribute('value', '');
        insertTarget.append(emptyOption);
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
export function displayListForModel(modelName, msg) {

    const insertTarget = getParentContainerForModelName(modelName).find('.clickable-list');

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

/* loadListForModel
 *
 * This pings the server for a list of items for the current accordian tab,
 * then populates the .clickable-list with them via displayListForModel()
 */
export function loadListForModel(modelName) {

    const urlForModel = {
        'event': 'eventsUpcoming',
    };
    const url = urlForModel[modelName] || `${modelName}All`;

    getParentContainerForModelName(modelName).find('.clickable-list' ).empty();
    $( `#${modelName}-display` ).first().hide();

    $.ajax({
        url: `${appUriBase}/${url}`,
        dataType: 'json'
    })
    .done( (msg) => { displayListForModel(modelName, msg) });
}

export function escapeHtml(unsafe) {
    unsafe = new String(unsafe); // is that right? else "unsafe.replace is not a function"
    return unsafe
         .replace(/&/g, '&amp;')
         .replace(/</g, '&lt;')
         .replace(/>/g, '&gt;')
         .replace(/'/g, '&quot;')
         .replace(/'/g, '&#039;');
}

export function getParentAndModelName(element) {
    const parentContainer = $(element).closest('[fold_model]');
    const modelName = parentContainer.attr('fold_model');
    return [parentContainer, modelName];
}
export function getParentContainerForModelName(modelName) {
    return $( `.accordion-container[fold_model="${modelName}"]` );
}

export function multiSelectOptionAdd() {
    const displayRow = $(this).closest('.display-row');
    const cloneTarget = displayRow.find('.multi-select-wrapper:last');
    const newSelectBoxDiv = cloneTarget.clone(true);
    cloneTarget.parent().append(newSelectBoxDiv);
    const newSelectBox = newSelectBoxDiv.find('select').first();
    newSelectBox.val('');
    newSelectBoxDiv.attr('cloned-selectlist', 1);
    return newSelectBox;
}


/* saveAction
 * action for the "Save" button on any of the forms
 */
export function saveAction(target, onSuccess) {

    const [parentContainer, modelName] = getParentAndModelName(target);

    const rowId = parentContainer.find(`[name="${modelName}_id"]` ).val();
    const activeForm = parentContainer.find( '.display-form' );
    
    // Run any helper functions that have been attached to the form
    activeForm[0].saveHelper.forEach(func => func(activeForm));

    // serialize() makes it into a query string like foo=1&bar=2,
    // and the ajax() turns that into json
    const dataString = activeForm.serialize();

    let http_method;
    let url;
    if (rowId) {
        http_method = 'put';
        url = `${appUriBase}/${modelName}/${rowId}`
    } else {
        http_method = 'post';
        url = `${appUriBase}/${modelName}/`;
    }
    $.ajax({
        url,
        dataType: 'json',
        method: http_method,
        data: dataString
    })
    .done( (msg) => {
        if (msg.errors.length > 0) {
            msg.errors.map((err) => alert(err.msg));
            return;
        }
        loadListForModel(modelName);
        displayItem(modelName, msg);
        if (onSuccess) {
            onSuccess();
        }
     })
    .fail( (err) => {
        handleError(err);
    });
}


export function deleteAction() {
    const modal = $( '#delete-confirmation-modal' );
    const modelName = modal.find( '[name="model-name"]' ).val();
    const fieldName = `${modelName}_id`;
    const idElement = $('#delete-confirmation-modal-id-el');
    const rowId = idElement.val();

    const url = `${appUriBase}/${modelName}/${rowId}`;

    $.ajax({
        url,
        dataType: 'json',
        method: 'put',
        data: 'is_deleted=1',
    })
    .done( (msg) => {
        if (msg.errors.length > 0) {
            msg.errors.map((err) => alert(err.msg));
            return;
        }
        loadListForModel(modelName);
        // it's now deleted, so hide this item
        const parentContainer = getParentContainerForModelName(modelName);
        parentContainer.find('.model-display').hide();
     })
    .fail( (err) => {
        handleError(err);
    });
}

/* handleError
 * generic response error handler
 * TODO this should be added to all the requests
 */
export function handleError(err) {
    switch (err.status){
        case 401:
            const signinUrl = err.responseJSON.data.url;
            $( '#login-redirect-modal-link' ).attr('href', signinUrl);
            loginRedirectModal.dialog( 'open' );
            break;
        case 403:
            insufficientPermissionsModal.dialog( 'open' );
            break;
        default:
            alert('something bad happened, update failed, see the server logs');
            console.log(err);
    }
}


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




