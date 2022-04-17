
 $( document ).ready(function() {

 $( '#load-event-button' ).click(function() {
    const eventId = $( '#event-id-input' )[0].value;
    $.ajax({
      url: `event/${eventId}`,
      dataType: "json"
    })
    .done( (msg) => { displayEvent(msg) });
  });

   loadEventList();

  $( '.all-events-list' ).change(function() {
    const eventId = $( '#all-events-list' )[0].value;
    $.ajax({
      url: `event/${eventId}`,
      dataType: "json"
    })
    .done( (msg) => { displayEvent(msg) });
  });

    $( '.event-display-row' ).click(function() {
        const display = $(this).children(".row-contents")[0];
        if (display.hidden) {
            return;
        }
        display.hidden = !display.hidden;
        const edit  = $(this).children(".row-edit")[0];
        edit.hidden = !edit.hidden;
    });

    // because we're handling the submit ourselves with the button
    $( '#event-display-form' ).submit(function(e){
        e.preventDefault();
    });

    $( '#event-save-button' ).click(function() {
        const eventId = $( '#event-display [name="event_id"]' )[0].value;
        const dataString = $( '#event-display-form' ).serialize();
        let http_method;
        let url;
        if (eventId) {
            http_method = "put";
            url = `event/${eventId}`
        } else {
            http_method = "post";
            url = "event/";
        }
        $.ajax({
            url,
            dataType: "json",
            method: http_method,
            data: dataString
        })
        .done( (msg) => { 
            loadEventList();
            displayEvent(msg);
         })
        .fail( () => { alert("something bad happened, update failed") }); // FIXME later
    });

    $( '#event-create-button' ).click(function() {
        $( '#event-display .event-display-row' ).each(
            function(index) {
                $(this).children(".row-contents")[0].hidden = true;
                $(this).children(".row-contents")[0].textContent = "";
                $(this).children(".row-edit")[0].hidden = false;
                $(this).children(".row-edit")[0].value = "";
            }
        );
        $( '#event-display [name="event_id"]' )[0].value = "";
        $( '#event-display' )[0].hidden = false;
    });
}); 

function displayEvent(msg) {

    if (msg["data"]) {
        const eventObj = msg["data"];
        $( '#event-display .event-display-row' ).each(
            function(index) {
                $(this).children(".row-contents")[0].hidden = false;
                $(this).children(".row-contents")[0].textContent = eventObj[this.getAttribute("name")];
                $(this).children(".row-edit")[0].hidden = true;
                $(this).children(".row-edit")[0].value = eventObj[this.getAttribute("name")];
            }
        );
        $( '#event-display [name="event_id"]' )[0].value = eventObj["event_id"]; 
        $( '#event-display' )[0].hidden = false;
    } else {
        alert("error: " + msg["error"]);
    }
}

function displayEventList(msg) {

    let insertTarget = $( "#all-events-list" );

    if (msg["data"]) {

        const events = msg["data"];

        events.forEach((event, i) => {
            let element = document.createElement('option');
            element.innerHTML = event["name"];
            element.setAttribute("value", event["event_id"]);
            insertTarget.append(element);
        });
    } else {
        alert("fail: " + msg["error"]);
    }
}

function loadEventList() {

    $( "#all-events-list" ).empty();
    $( "#event-display")[0].hidden = true;

    $.ajax({
        url: "events",
        dataType: "json"
    })
    .done( (msg) => { displayEventList(msg) });
}
