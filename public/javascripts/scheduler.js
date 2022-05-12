
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

        parentContainer.each(
            function(index) {
                $(this).find('.row-contents').hide();
                $(this).find('.row-contents').text('');
                $(this).find('.row-edit').show();
                $(this).find('.row-edit').val('');
            }
        );
        
        parentContainer.find(`[name="${modelName}_id"]` ).val('');
        parentContainer.find('.model-display').show();
    });

    $( '.accordion .label' ).click(function() {
        const [parentContainer, modelName] = getParentAndModelName(this);
        parentContainer.toggleClass('active')
        loadListForModel(modelName);
    });
}); 



// ********************************************
// other functions
// ********************************************

function displayItem(modelName, msg) {

    if (msg['data']) {
        const parentContainer = getContainerForModelName(modelName);
        const targetObj = msg['data'];
        parentContainer.find(`.display-row`).each(
            function(index) {
                $(this).children('.row-contents').show();
                $(this).children('.row-contents').text(targetObj[this.getAttribute('name')]);
                $(this).children('.row-edit').hide();
                $(this).children('.row-edit').val(targetObj[this.getAttribute('name')]);
            }
        );
        $( `[name="${modelName}_id"]` ).val(targetObj[`${modelName}_id`]);
        parentContainer.find('.model-display').show();
    } else {
        alert('error: ' + msg['error']);
    }
}

function displayListForModel(modelName, msg) {

    const insertTarget = getContainerForModelName(modelName).find('.clickable-list');

    if (msg['data']) {

        const rows = msg['data'];

        rows.forEach((row, i) => {
            let element = document.createElement('option');
            element.innerHTML = escapeHtml(row['name']);
            element.setAttribute('value', escapeHtml(row[`${modelName}_id`]));
            insertTarget.append(element);
        });
    } else {
        alert('fail: ' + msg['error']);
    }
}

function loadListForModel(modelName) {

    getContainerForModelName(modelName).find('.clickable-list' ).empty();
    $( `#${modelName}-display` ).first().hide();

    $.ajax({
        url: `${modelName}All`,
        dataType: 'json'
    })
    .done( (msg) => { displayListForModel(modelName, msg) });
}

function escapeHtml(unsafe) {
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
