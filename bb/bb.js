// buddybuild JS for GitBook

var BB;
if (!BB) BB = {
  BUTTON_ID:    '',
  PAGE:         '',
  NAV_SELECTOR: '.book-summary nav ul.summary'
};

BB.initEditTooltip = function () {
  var $bbedit = $(".bbedit");
  var $tip = $('<span>', {
    'class': 'tip',
    'html': 'Edit this page on GitHub'
  });

  $bbedit.addClass("tooltip");
  $bbedit.append($tip);
};

BB.makeCodeSamplesFancy = function () {
  $("pre.highlight").each(function () {
    $this = $(this);

    // highlight tokens in the examples, syntax= :token:
    var code = $("code", $this);
    code.html(fancyTokens(code.html()));

    // Add a copy button to all 'copyme' source examples
    if ($this.parent().parent().hasClass("copyme")) {
      var button = $('<button class="copy-to-clipboard">Copy</button>');
      $this.prepend(button);
    }
  });

  var clipboard = new Clipboard('.copy-to-clipboard', {
    target: function(trigger) {
      return trigger.nextElementSibling;
    }
  });
};

BB.enableSyntaxHighlighting = function () {
  $('pre code').each(function(i, block) {
    hljs.highlightBlock(block);
  });
};

BB.makePopularDocsClickable = function () {
  $(".popular-doc").on("click", function (e) {
    if (event.target == this) {
      window.location = $(this).find("a").attr("href");
      return false;
    }
  });
};

BB.makeShowMoreClickable = function () {
  $(".show-more a").on("click", function (e) {
    e.preventDefault();
    var elem = $(".show-more-extra");
    var $this = $(this);
    if (elem.is(":visible")) {
      elem.hide();
      $this.text("Show More");
    }
    else {
      elem.show();
      $this.text("Show Fewer");
    }
    return false;
  });
};

BB.tocInit = function () {
  // add click handler on all top-level nav elements to
  // expand/collapse their nested sub-topics.
  $(BB.NAV_SELECTOR)
    .children("li.chapter")
    .on("click", function (e) {
      BB.tocToggle($(this));
    });

  // mark all top-level entries as candidates for collapse
  $(BB.NAV_SELECTOR)
    .children("li.chapter")
    .addClass("collapse-me");

  // expand current entry, if any
  var activeChapter = BB.tocParent($(".chapter.active"));
  activeChapter.removeClass("collapse-me");
  tocExpand(activeChapter);

  // collapse all non-active top-level entries
  $(BB.NAV_SELECTOR)
    .children("li.chapter.collapse-me")
    .removeClass("collapse-me")
    .removeClass("expanded");
};

BB.tocToggle = function ($elem) {
  if ($elem.hasClass("expanded")) {
    BB.tocCollapse($elem);
  }
  else {
    BB.tocExpand($elem);
  }
};

BB.tocExpand = function ($elem) {
  if ($elem.length) {
    $elem.addClass("expanded");
  }
};

BB.tocCollapse = function ($elem) {
  if ($elem.length) {
    $elem.removeClass("expanded");
  }
};

// finds the top-most parent TOC item for the specified element.
BB.tocParent = function ($elem) {
  if ($elem.length) {
    var p = $elem.parents("li.chapter").last();
    if (p && p.length) return p;
  }
  return $elem;
};

BB.getPage = function () {
  return gitbook.state.page.title
         + gitbook.state.page.level
         + gitbook.state.page.depth;
}

BB.initScroll = function () {
  var headerOffset = 100;
  if (window.location.hash && window.location.hash.length) {
    var hash = window.location.hash.split("#")[1];
    var offset = findScrollOffset(hash);
    if (offset > headerOffset) offset -= headerOffset;
    if (offset >= 0) {
      $("html,body").animate({
        scrollTop: Math.floor(offset)
      }, 300);
    }
  }
  else {
    // Make sure that we scroll to the top of each new page.
    if (BB.PAGE != '') {
      var curPage = BB.getPage();
      if (BB.PAGE != curPage) {
        window.scrollTo(0, 0);
      }
    }
    BB.PAGE = BB.getPage();
  }
};

BB.findScrollOffset = function (hash) {
  if (hash === undefined || hash.length == 0) return 0;

  var target;

  switch (hash[0]) {
    case 'S':
      // Scroll to this percentage down the page
      var pct = Math.floor(hash.split("S")[1]);
      if (pct >= 0) {
        return Math.floor( $(".book-body").height() * pct / 100);
      }
      return BB.defaultScroll(hash);
      break;

    case 'P':
      // Scroll to the nth "paragraph" on the page
      var par = Math.floor(hash.split("P")[1]);
      if (par > 0) {
        target = $("p, dt, dd, pre, td, th, li", ".book .page-inner");
        if (target !== undefined
          && target.length
          && target[par - 1] !== undefined
        ) {
          return $(target[par - 1]).offset().top;
        }
      }
      return BB.defaultScroll(hash);
      break;

    case '/':
      // Scroll to the nth paragraph on the page
      var term = decodeURIComponent(hash.split("/")[1]);
      if (term !== undefined && term.length) {
        target = $(".book .page-inner .search-noresults *:contains('"+ term +"'):last");
        if (target !== undefined && target.length) {
          return $(target[0]).offset().top;
        }
      }
      return BB.defaultScroll(hash);
      break;

    default:
      return BB.defaultScroll(hash);
  }

  return 0;
};

BB.defaultScroll = function (hash) {
  if (document.getElementById(hash) !== null) {
    var target = $('#' + hash.replace(/\./g, "\\."));
    if (target !== undefined && target.length) {
      return target.offset().top;
    }
  }
  return 0;
};

BB.updateToolbarButtons = function () {
  if (!!BB.BUTTON_ID) {
    gitbook.toolbar.removeButton(BB.BUTTON_ID);
  }

  BB.BUTTON_ID = gitbook.toolbar.createButton({
    icon: 'fa fa-chevron-down',
    label: 'buddybuild links',
    className: 'bblinks',
    position: 'right',
    index: 0,
    dropdown: [
      [
        {
          text: 'buddybuild home',
          onClick: function(e) {
            e.preventDefault();
            window.open('https://www.buddybuild.com/');
          }
        }
      ],
      [
        {
          text: 'Docs',
          className: 'active'
        }
      ],
      [
        {
          text: 'Discussion Forum',
          onClick: function(e) {
            e.preventDefault();
            window.open('https://discuss.buddybuild.com/');
          }
        }
      ],
      [
        {
          text: 'Dashboard',
          onClick: function(e) {
            e.preventDefault();
            window.open('https://dashboard.buddybuild.com/');
          }
        }
      ],
      [
        {
          text: '',
          className: 'fa fa-facebook',
          onClick: function(e) {
            e.preventDefault();
            window.open('http://www.facebook.com/sharer/sharer.php?s=100&p[url]='+encodeURIComponent(location.href));
          }
        },
        {
          text: '',
          className: 'fa fa-twitter',
          onClick: function(e) {
            e.preventDefault();
            window.open('http://twitter.com/home?status='+encodeURIComponent(document.title+' '+location.href));
          }
        },
        {
          text: '',
          className: 'fa fa-google-plus',
          onClick: function(e) {
            e.preventDefault();
            window.open('https://plus.google.com/share?url='+encodeURIComponent(location.href));
          }
        }
      ]
    ]
  });
};
