
 $( document ).ready(function() {

    $( '.clickable-list' ).change(function() {
        const rowId = $(this).val();
        const [parentContainer, modelName] = getParentAndModelName(this);
        $.ajax({
            url: `${modelName}/${rowId}`,
            dataType: 'json'
        })
        .done( (msg) => { displayItem(modelName, msg) });
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

    $( '.save-button' ).click(function() {

        const [parentContainer, modelName] = getParentAndModelName(this);
        
        const rowId = parentContainer.find(`[name="${modelName}_id"]` ).val();
        const dataString = $( `#${modelName}-display-form` ).serialize();

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
         })
        .fail( () => { alert('something bad happened, update failed') }); // FIXME later
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
    });

    $( '.accordion .label' ).click(function() {
        const [parentContainer, modelName] = getParentAndModelName(this);
        parentContainer.toggleClass('active')
        if (parentContainer.hasClass('active')) {
            loadListForModel(modelName);
        }
    });

    $( '.add-multi-select-button' ).click(multiSelectOptionAdd);
}); 



// ********************************************
// other functions
// ********************************************

function displayItem(modelName, msg) {

    if (msg['data'] || msg === false) {
        const parentContainer = getContainerForModelName(modelName);
        const targetObj = msg ? msg['data'] : false;
        parentContainer.find('.display-row').each(
            (index, currentRow) => displayItemRow($(currentRow), targetObj)
        );
        parentContainer.find( `[name="${modelName}_id"]` ).val(targetObj ? targetObj[`${modelName}_id`] : '');
        parentContainer.find('.model-display').show();
    } else {
        alert('error: ' + msg['error']);
    }
}

/* getLabelForDisplayInItemListbox
 *
 * In the data returned from the server for listbox, we usually want to
 * pick the 'name' attribute to display, but in some cases we don't:
 */
const keyToDisplayInItemRow = {
    venue: 'vkey',
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
 * "row" is one thing for that, like "long_desc" or a listbox like "style" or
 * "venue".
 */
function displayItemRow(currentRow, targetObj) {

    currentRow.children('.row-contents').show();
    currentRow.children('.row-edit').hide();
    switch(currentRow.attr('column-type')) {
        case 'text-item':
            const theText = targetObj
                ? targetObj[currentRow.attr('name')]
                : '';
            currentRow.children('.row-contents').text(theText);
            currentRow.children('.row-edit').val(theText);
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
        if (selections.length) {
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
    const parentContainer = $(element).closest('.container');
    const modelName = parentContainer.attr('modelName');
    return [parentContainer, modelName];
}
function getContainerForModelName(modelName) {
    return $( `.container[modelName="${modelName}"]` );
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
