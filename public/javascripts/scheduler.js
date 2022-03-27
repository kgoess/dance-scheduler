
 $( document ).ready(function() {

  $( '#load-event-button' ).click(function() {
    const eventId = $( '#event-id-input' )[0].value;

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
      this.textContent = eventObj[this.id];
    }
  );
  $( '#event-display' ).show();

}
