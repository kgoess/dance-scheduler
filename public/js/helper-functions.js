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
                const theName = currentInput.getAttribute('name');
                const theValue = targetObj.hasOwnProperty(theName)
                    ? targetObj[theName]
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
 * pick the "name" attribute to display, but in some cases we don't.
 *
 * The fold_listbox_label_json element in accordions-webui.yml has entries like:
 *
 *    fold_listbox_label_json: '["start_date", "synthetic_name"]'
 *    fold_listbox_label_json: '"role_pair"'
 *
 * which accordion.tt displays in an HTML attriute like this:
 *
 *    data-fold_listbox_label='["start_date", "synthetic_name"]'
 *
 * which we're going to extract, and json-parse, and use to populate the listbox.
 *
 * https://developer.mozilla.org/en-US/docs/Learn_web_development/Howto/Solve_HTML_problems/Use_data_attributes
 */
const getLabelForDisplayInItemListbox = (modelName, data) => {

    let keyName = "name"; // default
    const fold_label_json = $(`.accordion-container[fold_model=${modelName}]`)
        .get(0)  // convert the first to an DOM node
        .dataset.fold_listbox_label; // accesses HTML attribute data-fold_listbox_label
    if (fold_label_json) {
        keyName = JSON.parse(fold_label_json);
    }
    if (Array.isArray(keyName)) {
        return keyName.map(item => data[item]).join(' - ');
    } else {
        return data[keyName];
    }
}

/* populated from accordion.tt from data in accordions-webui.yml, the
 * fold_listbox_label fields
 */
getLabelForDisplayInItemListbox.keyToDisplayInItemRow = { }
export { getLabelForDisplayInItemListbox };

/* displayItemRow
 *
 * The "item" is the thing we're displaying, like an event or a venue. This
 * "currentRow" is one thing for that, like "long_desc" or a listbox like
 * "style" or "venue".
 */
export function displayItemRow(currentRow, targetObj) {
    currentRow.children('.row-contents').show();
    currentRow.children('.row-edit').hide();
    currentRow.children('.input-disabler').hide();
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
            .done(msg => {
                unpackResults(
                    msg,
                    fillInItemRowList,
                    [currentRow, msg, selections, labelGetter]
                );
            })
            .fail( (err) => {
                handleError(err);
            });
            break;
        case 'text-item':
            let displayText = escapeHtml(singleValue);
            displayText = displayText.replace(/\n/g, '<br/>');
            currentRow.children('.row-contents').html(displayText);
            currentRow.children('.row-edit').val(singleValue);
            /* handle the thumbnail, which is in the div immediately following us */
            if (currentRow.attr('preview-image') && singleValue) {
                currentRow.next('.image-preview').each((i, row) => {
                    $(row).find('img').attr('src', singleValue);
                    // for the caption at the top. this "name||full_name" is
                    // admittedly inelegant
                    $(row).find('img').attr('alt', targetObj.name || targetObj.full_name);
                    $(row).show();
                });
                currentRow.next('.image-fullsize').each((i, row) => {
                    $(row).find('img').attr('src', singleValue);
                });
            } else {
                currentRow.next('.image-preview').hide();
            }
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
        // Remove any copies of the dropdown after the first, since we want to
        // start fresh (but we do need at least one)
        currentRow.find('.multi-select-wrapper:nth-of-type(n+2)').remove();
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
 * This pings the server for a list of items for the current accordion tab,
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
    .done(msg => {
        unpackResults(
            msg,
            displayListForModel,
            [modelName, msg]
        );
    })
    .fail( (err) => {
        handleError(err);
    });
}

export function escapeHtml(unsafe) {
    unsafe = new String(unsafe); 
    return unsafe
         .replace(/&/g, '&amp;')
         .replace(/</g, '&lt;')
         .replace(/>/g, '&gt;')
         .replace(/"/g, '&quot;')
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
    let dataString = activeForm.serialize();

    // if the form had an input-disabler field, make sure to submit it with a NULL if appropriate.
    activeForm[0].querySelectorAll('.input-disabler').forEach((e)=>{
        if (!e.checked){
            const relatedInput = e.parentElement.querySelector('.row-edit');
            if (relatedInput.value == '') dataString+=`&${relatedInput.getAttribute('name')}=NULL`;
        }
    })

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
    .done(msg => {
        unpackResults(
            msg,
            afterSaveSuccess,
            [msg, modelName, onSuccess]
        );
    })
    .fail( (err) => {
        handleError(err);
    });
}

/* 
 * The callback function for saveAction's ajax call.
 */
function afterSaveSuccess(msg, modelName, onSuccess){
    loadListForModel(modelName);
    displayItem(modelName, msg);
    $.toast({
        type: 'success',
        autoDismiss: true,
        message: `Saved ${modelName} successfully.`
      });
    if (onSuccess) {
        onSuccess();
    }
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
    .done(msg => {
        unpackResults(
            msg,
            (msg) => {
                loadListForModel(modelName);
                // it's now deleted, so hide this item
                const parentContainer = getParentContainerForModelName(modelName);
                parentContainer.find('.model-display').hide();
            }
        )
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
        case 426:
            $.toast({
                type: 'error',
                message: 'The backend scripts have been updated; please reload the page to continue.',
            });
            break;
        default:
            alert('something bad happened, update failed, see the server logs');
            console.log(err);
    }
}

/* unpackResults
 * Called by the .done() ajax handlers. The server returned a 200 response that
 * might have an error field in it. As opposed to a 3xx or whatever response
 * that would hit the ajax .fail() handler and end up in handleError above.
 *
 */
export function unpackResults(msg, cb, args) {
    if (msg.errors && msg.errors.length) {
        msg.errors.map((error) => { alert(error.msg) });
    } else {
        cb(...args);
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

/* Toast popup code from
 * https://codepen.io/kieran/pen/ajLvjm
 * this is used for the popup message after a user hits the save button
 */
export function toastInit(window, $){

  var toastDefaultConfig = {
    type: '',
    autoDismiss: false,
    container: '#toasts',
    autoDismissDelay: 4000,
    transitionDuration: 500
  };

  $.toast = function(config){
    var size = arguments.length;
    var isString = typeof(config) === 'string';
    
    if(isString && size === 1){
      config = {
        message: config
      };
    }

    if(isString && size === 2){
      config = {
        message: arguments[1],
        type: arguments[0]
      };
    }
    
    return new toast(config);
  };

  var toast = function(config){
    config = $.extend({}, toastDefaultConfig, config);
    // show "x" or not
    var close = config.autoDismiss ? '' : '&times;';
    
    // toast template
    var toast = $([
      '<div class="toast ' + config.type + '">',
      '<p>' + config.message + '</p>',
      '<div class="close">' + close + '</div>',
      '</div>'
    ].join(''));
    
    // handle dismiss
    toast.find('.close').on('click', function(){
      var toast = $(this).parent();

      toast.addClass('hide');

      setTimeout(function(){
        toast.remove();
      }, config.transitionDuration);
    });
    
    // append toast to toasts container
    $(config.container).append(toast);
    
    // transition in
    setTimeout(function(){
      toast.addClass('show');
    }, config.transitionDuration);

    // if auto-dismiss, start counting
    if(config.autoDismiss){
      setTimeout(function(){
        toast.find('.close').click();
      }, config.autoDismissDelay);
    }

    return this;
  }
}

