
 $( document ).ready(function() {

  $( '#load-event-button' ).click(function() {
    const eventId = $( '#event-id-input' )[0].value;
    $.ajax({
      url: `event/${eventId}`,
      dataType: "json"
    })
    .done( (msg) => { displayEvent(msg) });
  });

  $.ajax({
    url: "events",
    dataType: "json"
  })
  .done( (msg) => { displayEventList(msg) });

  $( '.all-events-list' ).change(function() {
    const eventId = $( '#all-events-list' )[0].value;
    $.ajax({
      url: `event/${eventId}`,
      dataType: "json"
    })
    .done( (msg) => { displayEvent(msg) });
  });

}); 


function displayEvent(eventObj) {
  $( '#event-display .event-display-row' ).each(
    function(index) {
      $(this).children(".row-contents")[0].textContent = eventObj[this.getAttribute("name")];
    }
  );
  $( '#event-display' ).show();
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
