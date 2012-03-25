app = {}

window.addEventListener "load", ->
  #バージョン整合性確認
  xhr = new XMLHttpRequest()
  xhr.open("GET", "/manifest.json?#{Date.now()}", false)
  xhr.send(null)
  app.manifest = JSON.parse(xhr.responseText)

  return if location.pathname isnt "/app.html"

  html_version = document.documentElement.getAttribute("data-app_version")
  if app.manifest.version isnt html_version
    location.reload(true)
    return

  #メニュー関連
  do ->
    #選択中のメニューに.selectedを付与する
    update_selected = ->
      old = document.querySelector("#left li.selected")
      old?.classList.remove("selected")
      now = document.querySelector("#left a[href=\"#{location.hash}\"]")
      now?.parentNode.classList.add("selected")
      return
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
      return
    return

  #コンテンツの表示に関わる処理
  do ->
    update_view = (view) ->
      container = document.getElementById("right")

      if container.firstChild?
        container.removeChild(container.firstChild)

      container.appendChild(view)
      return

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
    return
  return

do ->
  module = {}

  reg =
    supported: ///^http://(?:www\.youtube\.com/watch\?v=([^&]+)|www\.nicovideo\.jp/watch/[a-z]{2}(\d+))///
    youtube: ///^http://www\.youtube\.com/watch\?v=([^&]+)///
    nicovideo: ///^http://www\.nicovideo\.jp/watch/[a-z]{2}(\d+)///

  module.is_supported = (url) ->
    reg.supported.test(url)

  module.is_youtube = (url) ->
    reg.youtube.test(url)

  module.is_nicovideo = (url) ->
    reg.nicovideo.test(url)

  module.get_thumbnail_path = (url) ->
    if @is_youtube(url)
      res = reg.youtube.exec(url)
      "http://img.youtube.com/vi/#{res[1]}/default.jpg"

    else if @is_nicovideo(url)
      res = reg.nicovideo.exec(url)
      "http://tn-skr#{(parseInt(res[1], 10) % 4 + 1)}.smilevideo.jp/" +
        "smile?i=#{res[1]}"

    else
      null

  module.safe = (url) ->
    if /// ^https?:// ///.test(url) then url else "javascript:undefined;"

  app.url = module
  return

app.bookmark = {}

app.bookmark.get_available_folder = (callback) ->
  all_folder = []

  chrome.bookmarks.getTree (array_of_tree) ->
    fn = (tree) ->
      if "children" of tree
        all_folder.push(tree)
        tree.children.forEach(fn)
      return
    array_of_tree.forEach(fn)

    available_folder = all_folder.filter (tree) ->
      tree.children.some (tree) ->
        "url" of tree and app.url.is_supported(tree.url)

    callback(available_folder)
    return
  return
