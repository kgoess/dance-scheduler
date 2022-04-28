
 $( document ).ready(function() {

 $( '#load-event-button' ).click(function() {
    const eventId = $( '#event-id-input' )[0].value;
    $.ajax({
      url: `event/${eventId}`,
      dataType: 'json'
    })
    .done( (msg) => { displayItem('event', msg) });
  });

  $( '.all-event-list' ).change(function() {
    const eventId = $( '#all-event-list' )[0].value;
    $.ajax({
      url: `event/${eventId}`,
      dataType: 'json'
    })
    .done( (msg) => { displayItem('event', msg) });
  });

    $( '.event-display-row' ).click(function() {
        const display = $(this).children('.row-contents')[0];
        if (display.hidden) {
            return;
        }
        display.hidden = !display.hidden;
        const edit  = $(this).children('.row-edit')[0];
        edit.hidden = !edit.hidden;
    });

    // because we're handling the submit ourselves with the button
    $( '#event-display-form' ).submit(function(e){
        e.preventDefault();
    });

    $( '.save-button' ).click(function() {

        const parentContainer = $(this).closest('.container');
        const modelName = parentContainer.find('[name="modelName"]')[0].value;

        const rowId = parentContainer.find(`[name="${modelName}_id"]` )[0].value;
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
        
        const parentContainer = $(this).closest('.container');
        const modelName = parentContainer.find('[name=modelName]')[0].value;

        parentContainer.each(
            function(index) {
                $(this).find('.row-contents')[0].hidden = true;
                $(this).find('.row-contents')[0].textContent = '';
                $(this).find('.row-edit')[0].hidden = false;
                $(this).find('.row-edit')[0].value = '';
            }
        );
        
        parentContainer.find(`[name="${modelName}_id"]` )[0].value = '';
        $( `#${modelName}-display` )[0].hidden = false;
    });

    $( '.accordion .label' ).click(function() {
        const parentContainer = $(this).closest('.container');
        parentContainer.toggleClass('active')
        const modelName = parentContainer.find('[name=modelName]')[0].value;
        loadListForModel(modelName);
    });
}); 



// ********************************************
// other functions
// ********************************************

function displayItem(modelName, msg) {

    if (msg['data']) {
        const eventObj = msg['data'];
        $( `#${modelName}-display .${modelName}-display-row` ).each(
            function(index) {
                $(this).children('.row-contents')[0].hidden = false;
                $(this).children('.row-contents')[0].textContent = eventObj[this.getAttribute('name')];
                $(this).children('.row-edit')[0].hidden = true;
                $(this).children('.row-edit')[0].value = eventObj[this.getAttribute('name')];
            }
        );
        $( `#${modelName}-display [name="${modelName}_id"]` )[0].value = eventObj[`${modelName}_id`];
        $( `#${modelName}-display` )[0].hidden = false;
    } else {
        alert('error: ' + msg['error']);
    }
}

function displayListForModel(modelName, msg) {

    let insertTarget = $( `#all-${modelName}-list` );

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

    $( `#all-${modelName}-list` ).empty();
    $( `#${modelName}-display` ).first().hidden = true;

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

