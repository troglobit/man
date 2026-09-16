/*
 * man.troglobit.com -- theme, page search and in-page contents.
 *
 * Everything here is progressive: without JavaScript the pages still read,
 * navigate and print.  Only the search box and the theme button go quiet.
 */
(function () {
	"use strict";

	var PREFIX = document.currentScript
		? document.currentScript.dataset.prefix
		: (document.querySelector("script[data-prefix]") || {dataset: {}}).dataset.prefix;

	if (typeof PREFIX !== "string")
		PREFIX = "";

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

	/* ----------------------------------------------------------- search */

	var box     = document.getElementById("q");
	var list    = document.getElementById("results");
	var pages   = null;
	var pending = false;
	var hits    = [];
	var at      = -1;

	function load()
	{
		if (pages || pending)
			return Promise.resolve();

		pending = true;
		return fetch(PREFIX + "pages.json")
			.then(function (r) { return r.json(); })
			.then(function (d) { pages = d; pending = false; })
			.catch(function () {
				pending = false;
				pages = [];
			});
	}

	function esc(s)
	{
		return s.replace(/[&<>"]/g, function (c) {
			return {"&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;"}[c];
		});
	}

	function mark(text, needle)
	{
		var i = needle ? text.toLowerCase().indexOf(needle) : -1;

		if (i < 0)
			return esc(text);

		return esc(text.slice(0, i)) + "<mark>" +
			esc(text.slice(i, i + needle.length)) + "</mark>" +
			esc(text.slice(i + needle.length));
	}

	/*
	 * "syslog", "syslog 3", "syslog(3)" and "syslog.3" all mean the same
	 * thing to someone who reads manual pages, so accept all four.
	 */
	function parse(raw)
	{
		var q = raw.trim().toLowerCase();
		var m = q.match(/^(.*?)[\s.(]+([1-9])\)?$/);

		if (m)
			return {name: m[1].trim(), sect: m[2]};

		return {name: q, sect: null};
	}

	function rank(p, q)
	{
		var n = p.n.toLowerCase();
		var i;

		if (n === q)              return 0;
		if (n.indexOf(q) === 0)   return 1;
		if (n.indexOf(q) > 0)     return 2;

		if (p.a) {
			for (i = 0; i < p.a.length; i++) {
				if (p.a[i].toLowerCase().indexOf(q) >= 0)
					return 3;
			}
		}

		if (p.d && p.d.toLowerCase().indexOf(q) >= 0)
			return 4;

		return -1;
	}

	function search(raw)
	{
		var q = parse(raw);
		var out = [];

		if (!pages || (!q.name && !q.sect))
			return [];

		pages.forEach(function (p) {
			var score;

			if (q.sect && p.s !== q.sect)
				return;

			if (!q.name) {
				out.push({p: p, score: 1});
				return;
			}

			score = rank(p, q.name);
			if (score >= 0)
				out.push({p: p, score: score});
		});

		out.sort(function (a, b) {
			return a.score - b.score ||
				a.p.n.length - b.p.n.length ||
				a.p.n.localeCompare(b.p.n) ||
				a.p.s.localeCompare(b.p.s);
		});

		return out.slice(0, 40).map(function (o) { return o.p; });
	}

	function select(i)
	{
		var items = list.children;
		var el;

		if (at >= 0 && items[at])
			items[at].removeAttribute("aria-selected");

		at = i;
		if (at < 0 || !items[at]) {
			box.removeAttribute("aria-activedescendant");
			return;
		}

		el = items[at];
		el.setAttribute("aria-selected", "true");
		box.setAttribute("aria-activedescendant", el.id);
		el.scrollIntoView({block: "nearest"});
	}

	function close()
	{
		list.hidden = true;
		list.innerHTML = "";
		box.setAttribute("aria-expanded", "false");
		box.removeAttribute("aria-activedescendant");
		hits = [];
		at = -1;
	}

	function render(raw)
	{
		var q = parse(raw);

		hits = search(raw);
		at = -1;

		if (!raw.trim()) {
			close();
			return;
		}

		if (!hits.length) {
			list.innerHTML = "<li class=\"none\">No manual page matches " +
				esc(raw.trim()) + "</li>";
		} else {
			list.innerHTML = hits.map(function (p, i) {
				return "<li id=\"r" + i + "\" role=\"option\" data-s=\"" +
					esc(p.s) + "\"><a href=\"" + PREFIX + esc(p.u) + "\">" +
					"<span class=\"nm\">" + mark(p.n, q.name) + "</span>" +
					"<span class=\"sc\">(" + esc(p.s) + ")</span>" +
					"<span class=\"nd\">" + mark(p.d || "", q.name) + "</span>" +
					"</a></li>";
			}).join("");
		}

		list.hidden = false;
		box.setAttribute("aria-expanded", "true");
	}

	if (box && list) {
		box.addEventListener("focus", load);

		box.addEventListener("input", function () {
			var raw = box.value;

			load().then(function () {
				if (box.value === raw)
					render(raw);
			});
		});

		box.addEventListener("keydown", function (ev) {
			if (ev.key === "Escape") {
				if (list.hidden) {
					box.value = "";
					box.blur();
				} else {
					close();
				}
				return;
			}

			if (ev.key === "Enter") {
				if (at >= 0 && hits[at]) {
					ev.preventDefault();
					location.href = PREFIX + hits[at].u;
				} else if (hits.length) {
					ev.preventDefault();
					location.href = PREFIX + hits[0].u;
				}
				return;
			}

			if (list.hidden || !hits.length)
				return;

			if (ev.key === "ArrowDown") {
				ev.preventDefault();
				select((at + 1) % hits.length);
			} else if (ev.key === "ArrowUp") {
				ev.preventDefault();
				select(at <= 0 ? hits.length - 1 : at - 1);
			}
		});

		document.addEventListener("click", function (ev) {
			if (!ev.target.closest(".find"))
				close();
		});

		/* "/" is the pager's search key, so it is the one people try. */
		document.addEventListener("keydown", function (ev) {
			var tag;

			if (ev.key !== "/" || ev.ctrlKey || ev.metaKey || ev.altKey)
				return;

			tag = document.activeElement && document.activeElement.tagName;
			if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT")
				return;

			ev.preventDefault();
			box.focus();
			box.select();
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
