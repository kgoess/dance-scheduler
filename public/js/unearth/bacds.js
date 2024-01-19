document.addEventListener('DOMContentLoaded', function() {
  var calendarEl = document.getElementById('calendar');
  var calendar = new FullCalendar.Calendar(calendarEl, {
    initialView: 'dayGridMonth',

    headerToolbar: { center: 'dayGridMonth,timeGridWeek' }, // buttons for switching between views

      defaultTimedEventDuration: '02:30',
    events: {   
      url: bacds.baseUri+'/livecalendar-results',
      failure: function() {
        alert('there was an error while fetching events!');
      },
    },
    eventDisplay: 'block',

    eventClick: function(event) {
      if (event.url) {
        window.open(event.url);
        return false;
      }
    },

  })
  calendar.render();
});
