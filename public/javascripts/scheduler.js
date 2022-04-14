
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
        $.ajax({
            url: `event/${eventId}`,
            dataType: "json",
            method: "post",
            data: dataString
        })
        .done( (msg) => { 
            loadEventList();
            $.ajax({
              url: `event/${eventId}`,
              dataType: "json"
            })
            .done( (msg) => { displayEvent(msg) });
         })
        .fail( () => { alert("something bad happened, update failed") }); // FIXME later
    });


}); 

function displayEvent(eventObj) {
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
}

function displayEventList(events) {

    let insertTarget = $( "#all-events-list" );

    events.forEach((event, i) => {
        let element = document.createElement('option');
        element.innerHTML = event["name"];
        element.setAttribute("value", event["event_id"]);
        insertTarget.append(element);
    });
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
