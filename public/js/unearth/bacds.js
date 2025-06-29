document.addEventListener("DOMContentLoaded", function () {
  let eventsUrl = "/dance-scheduler/livecalendar-results";
  if (Number(location.port) >= 5000) {
    eventsUrl = '/livecalendar-results';
  }
  var calendarEl = document.getElementById("calendar");
  if (calendarEl) {
      var calendar = new FullCalendar.Calendar(calendarEl, {
        initialView: "dayGridMonth",

        headerToolbar: { center: "dayGridMonth,timeGridWeek" }, // buttons for switching between views

        defaultTimedEventDuration: "02:30",
        events: {
          url: eventsUrl,
          failure: function () {
            alert("there was an error while fetching events!");
          },
        },
        eventDisplay: "block",

        eventClick: function (event) {
          if (event.url) {
            window.open(event.url);
            return false;
          }
        },
      });
      calendar.render();
    }
});

/** multi-level dropdown code from https://stackoverflow.com/a/66470962 */
(function ($bs) {
  const CLASS_NAME = "has-child-dropdown-show";
  $bs.Dropdown.prototype.toggle = (function (_orginal) {
    return function () {
      document.querySelectorAll("." + CLASS_NAME).forEach(function (e) {
        e.classList.remove(CLASS_NAME);
      });
      let dd = this._element
        .closest(".dropdown")
        .parentNode.closest(".dropdown");
      for (; dd && dd !== document; dd = dd.parentNode.closest(".dropdown")) {
        dd.classList.add(CLASS_NAME);
      }
      return _orginal.call(this);
    };
  })($bs.Dropdown.prototype.toggle);

  document.querySelectorAll(".dropdown").forEach(function (dd) {
    dd.addEventListener("hide.bs.dropdown", function (e) {
      if (this.classList.contains(CLASS_NAME)) {
        this.classList.remove(CLASS_NAME);
        e.preventDefault();
      }
      e.stopPropagation(); // do not need pop in multi level mode
    });
  });

  // for hover
  document
    .querySelectorAll(".dropdown-hover, .dropdown-hover-all .dropdown")
    .forEach(function (dd) {
      dd.addEventListener("mouseenter", function (e) {
        let toggle = e.target.querySelector(
          ':scope>[data-bs-toggle="dropdown"]'
        );
        if (!toggle.classList.contains("show")) {
          $bs.Dropdown.getOrCreateInstance(toggle).toggle();
          dd.classList.add(CLASS_NAME);
          $bs.Dropdown.clearMenus();
        }
      });
      dd.addEventListener("mouseleave", function (e) {
        let toggle = e.target.querySelector(
          ':scope>[data-bs-toggle="dropdown"]'
        );
        if (toggle.classList.contains("show")) {
          $bs.Dropdown.getOrCreateInstance(toggle).toggle();
        }
      });
    });
})(bootstrap);
