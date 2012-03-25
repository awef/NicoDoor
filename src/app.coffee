app = {}

window.addEventListener "load", ->
  xhr = new XMLHttpRequest()
  xhr.open("GET", "/manifest.json?#{Date.now()}", false)
  xhr.send(null)
  app.manifest = JSON.parse(xhr.responseText)

  if location.pathname is "/app.html"
    html_version = document.documentElement.getAttribute("data-app_version")
    if app.manifest.version isnt html_version
      location.reload(true)
    else
      app.main()

app.main = ->
  #メニュー関連
  do ->
    #選択中のメニューに.selectedを付与する
    update_selected = ->
      old = document.querySelector("#left li.selected")
      old?.classList.remove("selected")
      now = document.querySelector("#left a[href=\"#{location.hash}\"]")
      now?.parentNode.classList.add("selected")
    window.addEventListener("hashchange", update_selected)

    #ブックマークメニューの構築
    ul = document.querySelector(".bookmark_menu > ul")
    app.bookmark.get_available_folder (array_of_tree) ->
      for tree in array_of_tree
        li = document.createElement("li")
        a = document.createElement("a")
        a.href = "#!/bookmark/#{encodeURIComponent(tree.id)}"
        a.textContent = tree.title
        li.appendChild(a)
        ul.appendChild(li)
        update_selected()

  #コンテンツの表示に関わる処理
  do ->
    update_view = (view) ->
      container = document.getElementById("right")

      if container.firstChild?
        container.removeChild(container.firstChild)

      container.appendChild(view)

    on_hashchange = ->
      res = ///^\#\!/bookmark/(.*)$///.exec(location.hash)
      if res
        update_view(app.view.bookmark(decodeURIComponent(res[1])))
        return

      res = ///^\#\!/ranking/(.*)$///.exec(location.hash)
      if res
        update_view(app.view.ranking(res[1]))
      else
        location.hash = "#!/ranking/fav/hourly/all"

    on_hashchange()
    window.addEventListener("hashchange", on_hashchange, false)

app.url = {}

app.url._reg =
  supported: ///^http://(?:www\.youtube\.com/watch\?v=([^&]+)|www\.nicovideo\.jp/watch/[a-z]{2}(\d+))///
  youtube: ///^http://www\.youtube\.com/watch\?v=([^&]+)///
  nicovideo: ///^http://www\.nicovideo\.jp/watch/[a-z]{2}(\d+)///

app.url.is_supported = (url) ->
  app.url._reg.supported.test(url)

app.url.is_youtube = (url) ->
  app.url._reg.youtube.test(url)

app.url.is_nicovideo = (url) ->
  app.url._reg.nicovideo.test(url)

app.url.get_thumbnail_path = (url) ->
  if app.url.is_youtube(url)
    res = app.url._reg.youtube.exec(url)
    "http://img.youtube.com/vi/#{res[1]}/default.jpg"

  else if app.url.is_nicovideo(url)
    res = app.url._reg.nicovideo.exec(url)
    "http://tn-skr#{(parseInt(res[1], 10) % 4 + 1)}.smilevideo.jp/" +
      "smile?i=#{res[1]}"

  else
    null

app.url.safe = (url) ->
  if /// ^https?:// ///.test(url) then url else "javascript:undefined;"

app.bookmark = {}

app.bookmark.get_available_folder = (callback) ->
  all_folder = []

  chrome.bookmarks.getTree (array_of_tree) ->
    fn = (tree) ->
      if "children" of tree
        all_folder.push(tree)
        tree.children.forEach(fn)
    array_of_tree.forEach(fn)

    available_folder = all_folder.filter (tree) ->
      tree.children.some (tree) ->
        "url" of tree and app.url.is_supported(tree.url)

    callback(available_folder)

