/*
 * man.troglobit.com -- theme, page search and in-page contents.
 *
 * Everything here is progressive: without JavaScript the pages still read,
 * navigate and print.  Only the search box and the theme button go quiet.
 */
(function () {
	"use strict";

	/* ------------------------------------------------------------ theme */

	var root  = document.documentElement;
	var theme = document.querySelector(".theme");
	var modes = ["auto", "light", "dark"];
	var label = {
		auto:  "Theme: auto, following your system. Click for light.",
		light: "Theme: light. Click for dark.",
		dark:  "Theme: dark. Click for auto."
	};

	function store(key, val)
	{
		try {
			if (val === null)
				localStorage.removeItem(key);
			else
				localStorage.setItem(key, val);
		} catch (e) {}
	}

	function read(key)
	{
		try {
			return localStorage.getItem(key);
		} catch (e) {
			return null;
		}
	}

	/* Anything else in storage, including nothing at all, means auto. */
	function mode()
	{
		var t = read("theme");

		return t === "light" || t === "dark" ? t : "auto";
	}

	function paint(m)
	{
		root.setAttribute("data-theme", m);

		if (theme) {
			theme.title = label[m];
			theme.setAttribute("aria-label", label[m]);
		}
	}

	if (theme) {
		paint(mode());
		theme.addEventListener("click", function () {
			var next = modes[(modes.indexOf(mode()) + 1) % modes.length];

			store("theme", next === "auto" ? null : next);
			paint(next);
		});
	}

	/* -------------------------------------------------- in-page contents */

	/*
	 * The contents are a rail beside the text on a wide screen and a
	 * disclosure on a narrow one.  Pages ship it open so that it is there
	 * either way without JavaScript; fold it away when it would otherwise
	 * push the manual page itself off the screen.
	 */
	var toc = document.querySelector(".toc details");

	if (toc && window.matchMedia("(max-width: 61.999rem)").matches)
		toc.removeAttribute("open");

	var links = document.querySelectorAll(".toc a[href^='#']");

	if (links.length && "IntersectionObserver" in window) {
		var byId = {};
		var seen = [];

		links.forEach(function (a) {
			byId[decodeURIComponent(a.hash.slice(1))] = a;
		});

		var spy = new IntersectionObserver(function (entries) {
			entries.forEach(function (e) {
				var id = e.target.id;

				if (e.isIntersecting) {
					if (seen.indexOf(id) < 0)
						seen.push(id);
				} else {
					seen = seen.filter(function (s) { return s !== id; });
				}
			});

			links.forEach(function (a) { a.removeAttribute("aria-current"); });

			if (seen.length) {
				var first = Object.keys(byId).filter(function (id) {
					return seen.indexOf(id) >= 0;
				})[0];

				if (first && byId[first])
					byId[first].setAttribute("aria-current", "true");
			}
		}, {rootMargin: "-72px 0px -70% 0px"});

		Object.keys(byId).forEach(function (id) {
			var h = document.getElementById(id);

			if (h)
				spy.observe(h);
		});
	}
}());
