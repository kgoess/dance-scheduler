/*   Project: Popup Lightbox 
 *   Author: Asif Mughal
 *   URL: www.codehim.com
 *   License: MIT License
 *   Copyright (c) 2019 - Asif Mughal
 */
/* File: jquery.popup.lightbox.js */
(function ($) {
	$.fn.popupLightbox = function (options) {

		var setting = $.extend({
			width: 500,
			height: 500,
			inAnimation: "ZoomIn",

		}, options);

		return this.each(function () {

			var target = $(this);

			var popupWindow = $section();

			var imgFig = $figure();

			var capBar = $figcaption();

			var imgs = $(target).find("img");

			$(imgFig).addClass("img-show")
				.appendTo(popupWindow);

			$(popupWindow).addClass("lightbox animated faster " + setting.inAnimation).appendTo("body");



			if ($(window).width() > 620) {

				$(popupWindow).css({
					'width': setting.width,
					'height': setting.height,
					'position': 'fixed',
					'top': '50%',
					'marginTop': -(setting.height / 2),
					'left': '50%',
					'marginLeft': -(setting.width / 2),
					'zIndex': '999',
					'overflow': 'hidden',
				});

			} else {
				$(popupWindow).css({
					'width': '100%',
					'height': '100%',
					'top': 0,
					'left': 0,
				});
			}


			$(capBar).addClass("img-caption animated fadeInUp");

			$(imgs).click(function () {
				var thisImg = $(this).clone();
				var $caption = $(this).attr('alt');
				if ($(this).prop('alt') == false) {
					$caption = "This image has no caption";
				}

				$(imgFig).html(thisImg)
					.parent().fadeIn();

				$(capBar).html($caption).appendTo(imgFig);
			});


			function $section() {
				return document.createElement("section");
			}

			function $figure() {
				return document.createElement("figure");
			}

			function $figcaption() {
				return document.createElement("figcaption");
			}

			$(popupWindow).click(function () {
				$(this).fadeOut();
			});
		});
	};

})(jQuery);
