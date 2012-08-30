window.addEventListener("load", function () {
  if (location.pathname === "/app.html") {
    new window.App(document.documentElement);
  }
});

(function () {
  "use strict";

  var App;

  App = function (element) {
    var app, xhr, htmlVersion;

    app = this;

    this.element = element;

    xhr = new XMLHttpRequest();
    xhr.open("GET", "/manifest.json?#{Date.now()}", false);
    xhr.send();
    this.manifest = JSON.parse(xhr.responseText);

    htmlVersion = this.element.getAttribute("data-app_version");

    if (this.manifest.version !== htmlVersion) {
      location.reload(true);
    }
    else {
      // メニュー関連
      (function () {
        var updateSelected, ul;

        // 選択中の項目に.selectedを付与する
        updateSelected = function () {
          var old, now;

          if (old = app.element.querySelector("#left li.selected")) {
            old.classList.remove("selected");
          }
          if (now = app.element.querySelector("#left a[href=\"" + location.hash + "\"]")) {
            now.parentNode.classList.add("selected");
          }
        };
        window.addEventListener("hashchange", updateSelected);

        // ブックマークメニュー構築
        ul = app.element.querySelector(".bookmark_menu > ul");
        App.Bookmark.getAvailableFolder(function (arrayOfTree) {
          arrayOfTree.forEach(function (tree) {
            var li, a;

            li = document.createElement("li");
            a = document.createElement("a");
            a.href = "#!/bookmark/" + encodeURIComponent(tree.id);
            a.textContent = tree.title;
            li.appendChild(a);
            ul.appendChild(li);
          });

          updateSelected();
        });
      })();

      // コンテンツの表示に関わる処理
      (function () {
        var updateView, onHashchange;

        updateView = function (view) {
          var container;

          container = app.element.querySelector("#right");

          if (container.firstChild) {
            container.removeChild(container.firstChild);
          }

          container.appendChild(view);
        };

        onHashchange = function () {
          var res;

          if (res = /^\#\!\/bookmark\/(.*)$/.exec(location.hash)) {
            updateView((new App.View.Bookmark(decodeURIComponent(res[1]))).element);
          }
          else if (res = /^#\!\/ranking\/(.*)$/.exec(location.hash)) {
            updateView((new App.View.Ranking(res[1])).element);
          }
          else {
            location.hash = "#!/ranking/fav/hourly/all";
          }
        };

        onHashchange()
        window.addEventListener("hashchange", onHashchange);
      })();
    }
  };

  App.URL = function () {};

  App.URL._reg = {
    supported: /^http:\/\/(?:www\.youtube\.com\/watch\?v=([^&]+)|www\.nicovideo\.jp\/watch\/[a-z]{2}(\d+))/,
    youtube: /^http:\/\/www\.youtube\.com\/watch\?v=([^&]+)/,
    nicovideo: /^http:\/\/www\.nicovideo\.jp\/watch\/[a-z]{2}(\d+)/
  };

  App.URL.isSupported = function (url) {
    return this._reg.supported.test(url);
  };

  App.URL.isYoutube = function (url) {
    return this._reg.youtube.test(url);
  };

  App.URL.isNicovideo = function (url) {
    return this._reg.nicovideo.test(url);
  };

  App.URL.getThumbnailPath = function (url) {
    var res;

    if (res = this._reg.youtube.exec(url)) {
      return "http://img.youtube.com/vi/" + res[1] + "/default.jpg";
    }
    else if (res = this._reg.nicovideo.exec(url)) {
      return (
        "http://tn-skr" + (parseInt(res[1], 10) % 4 + 1) + ".smilevideo.jp/" +
        "smile?i=" + res[1]
      );
    }
    else {
      return null;
    }
  };

  App.URL.safe = function (url) {
    if (/^https?:\/\//.test(url)) {
      return url;
    }
    else {
      return "data:text/plain,dummy";
    }
  };

  App.Bookmark = function () {};

  App.Bookmark.getAvailableFolder = function (callback) {
    var folder = [];

    chrome.bookmarks.getTree(function (arrayOfTree) {
      var fn;

      fn = function (tree) {
        if ("children" in tree) {
          folder.push(tree);
          tree.children.forEach(fn);
        }
      };

      arrayOfTree.forEach(fn);

      folder = folder.filter(function (tree) {
        return tree.children.some(function (tree) {
          return ("url" in tree) && App.URL.isSupported(tree.url);
        });
      });

      callback(folder);
    });
  };

  App.View = {};

  App.View.ItemList = function () {
    var view, header, h1, input, frag;

    view = this;

    this.element = document.createElement("div");
    this.element.classList.add("view_item_list");

    header = document.createElement("header");
    this.element.appendChild(header);

    h1 = document.createElement("h1");
    header.appendChild(h1);

    input = document.createElement("input");
    input.placeholder = "Search";
    header.appendChild(input);

    input.addEventListener("input", function () {
      var query;

      view.element.classList.add("searching");

      Array.prototype.forEach.call(
        view.getElementsByClassName("search_hit"),
        function (tmp) {
          tmp.classList.remove("search_hit");
        }
      );

      query = this.value.toLowerCase();

      if (query) {
        Array.prototype.forEach.call(
          view.getElementsByTagName("a"),
          function (tmp) {
            if (tmp.title.toLowerCase().indexOf(query) !== -1) {
              tmp.classList.add("search_hit");
            }
          }
        );
      }
      else {
        view.classList.remove("searching");
      }
    });

    input.addEventListener("keyup", function (e) {
      if (e.which === 27) { //Esc
        this.value = "";
        view.classList.remove("searching");
      }
    });
  };

  App.View.ItemList.prototype = {
    setTitle: function (title) {
      this.element.querySelector("h1").textContent = title;
    },
    addItem: function (itemList) {
      var frag;

      if (!Array.isArray(itemList)) {
        itemList = [itemList];
      }

      frag = document.createDocumentFragment();
      itemList.forEach(function (item) {
        var a, img;

        a = document.createElement("a");
        a.href = App.URL.safe(item.url);
        a.title = item.title;
        img = document.createElement("img");
        img.src = App.URL.getThumbnailPath(item.url);
        a.appendChild(img);
        frag.appendChild(a);
      });

      this.element.appendChild(frag);
    }
  };

  App.View.Ranking = function (rankingId) {
    var view, itemList, xhr, xhrPath, xhrTimer, message;

    if (!/^fav\/(?:hourly|daily)\/\w+$/.test(rankingId)) {
      console.error("App.View.Ranking: 不正な引数です", arguments);
      return;
    }

    view = this;

    itemList = new App.View.ItemList();
    this.element = itemList.element;
    this.element.classList.add("view_ranking");

    xhrPath = "http://www.nicovideo.jp/ranking/" + rankingId + "?rss=atom";
    xhrPath += "&_=" + Date.now();

    message = document.createElement("div");
    message.className = "message";
    message.textContent = "ランキングのデータを取得中";
    this.element.appendChild(message);

    xhr = new XMLHttpRequest();
    xhrTimer = setTimeout(xhr.abort.bind(xhr), 30 * 1000);
    xhr.onreadystatechange = function () {
      var xml, items, rankTitle;

      if (this.readyState === 4) {
        clearTimeout(xhrTimer);

        if (this.status === 200) {
          items = [];

          xml = this.responseXML;
          if (xml) {
            if (xml.querySelector("feed > title")) {
              itemList.setTitle(xml.querySelector("feed > title").textContent);
            }
            Array.prototype.forEach.call(
              xml.getElementsByTagName("entry"),
              function (entry) {
                var title, link;

                title = entry.querySelector("title");
                link = entry.querySelector("link");
                if (title && link) {
                  items.push({
                    title: title.textContent,
                    url: link.getAttribute("href")
                  });
                }
              }
            );

            itemList.addItem(items);
            message.parentNode.removeChild(message);
          }
          else {
            message.classList.add("error");
            message.textContent = "通信エラー（パース失敗）";
          }
        }
        else {
          message.classList.add("error");
          message.textContent = "通信エラー (エラーコード: " + this.status + ")";
        }
      }
    };
    xhr.open("GET", xhrPath);
    xhr.send();
  };

  App.View.Bookmark = function (bookmarkId) {
    var view, itemList;

    view = this;

    itemList = new App.View.ItemList();
    this.element = itemList.element;
    this.element.classList.add("view_bookmark");

    chrome.bookmarks.get(bookmarkId, function (arrayOfTree) {
      var message;

      if (arrayOfTree && typeof arrayOfTree[0].title === "string") {
        itemList.setTitle(arrayOfTree[0].title);

        chrome.bookmarks.getChildren(bookmarkId, function (arrayOfTree) {
          var items;

          items = [];
          arrayOfTree.forEach(function (tree) {
            if ("url" in tree && App.URL.isSupported(tree.url)) {
              items.push({
                url: tree.url,
                title: tree.title.replace(/^(.+)\u0020\u2010\u0020\u30cb\u30b3\u30cb\u30b3\u52d5\u753b\u0028.*\u0029$/, "$1")
              });
            }
          });

          itemList.addItem(items);
        });
      }
      else {
        message = document.createElement("div");
        message.className = "message error";
        message.textContent = "指定されたフォルダは存在しません";
        view.element.appendChild(message);
      }
    });
  };

  window.App = App;
})();
