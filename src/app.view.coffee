app.view = {}

app.view.ranking = (ranking_id) ->
  if not /// ^fav/(?:hourly|daily)/\w+$ ///.test(ranking_id)
    console.error("app.view.ranking: 不正な引数です", arguments)
    return

  view = document.createElement("div")
  view.className = "view_ranking"

  xhr_path = "http://www.nicovideo.jp/ranking/#{ranking_id}?rss=atom"
  xhr_path += "&_=#{Date.now()}"

  message = document.createElement("div")
  message.className = "message"
  message.textContent = "ランキングのデータを取得中"
  view.appendChild(message)

  xhr = new XMLHttpRequest()
  xhr_timer = setTimeout((-> xhr.abort(); return), 30 * 1000)
  xhr.onreadystatechange = ->
    if xhr.readyState is 4
      clearTimeout(xhr_timer)

      if xhr.status is 200
        item_list = []

        xml = xhr.responseXML
        if xml
          rank_title = xml.querySelector("feed > title")?.textContent
          for entry in xml.getElementsByTagName("entry")
            title = entry.getElementsByTagName("title")[0]?.textContent
            url = entry.getElementsByTagName("link")[0]?.getAttribute("href")
            if title and url
              item_list.push({title, url})

          app.view.item_list(rank_title or "", item_list, view)
          message.parentNode.removeChild(message)
        else
          message.classList.add("error")
          message.textContent = "通信エラー（パース失敗）"
      else
        message.classList.add("error")
        message.textContent = "通信エラー (エラーコード: #{xhr.status})"
    return
  xhr.open("GET", xhr_path)
  xhr.send(null)

  view

app.view.bookmark = (bookmark_id) ->
  view = document.createElement("div")
  view.className = "view_bookmark"

  chrome.bookmarks.get bookmark_id, (array_of_tree) ->
    title = array_of_tree?[0]?.title

    if not title
      message = document.createElement("div")
      message.className = "message error"
      message.textContent = "指定されたフォルダは存在しません"
      view.appendChild(message)
      return

    chrome.bookmarks.getChildren bookmark_id, (array_of_tree) ->
      item_list = []
      for tree in array_of_tree
        if "url" of tree and app.url.is_supported(tree.url)
          item_list.push
            url: tree.url
            title: tree.title.replace(/^(.+)\u0020\u2010\u0020\u30cb\u30b3\u30cb\u30b3\u52d5\u753b\u0028.*\u0029$/, "$1")

      app.view.item_list(title, item_list, view)
      return
    return
  view

app.view.item_list = (title, item_list, view) ->
  view or= document.createElement("div")
  view.classList.add("view_item_list")

  header = document.createElement("header")
  view.appendChild(header)

  h1 = document.createElement("h1")
  h1.innerText = title
  header.appendChild(h1)

  input = document.createElement("input")
  input.placeholder = "Search"

  input.addEventListener "input", ->
    view.classList.add("searching")

    for tmp in Array.prototype.slice.apply(view.getElementsByClassName("search_hit"))
      tmp.classList.remove("search_hit")

    query = this.value.toLowerCase()
    if query
      for tmp in view.getElementsByTagName("a")
        if tmp.title.toLowerCase().indexOf(query) isnt -1
          tmp.classList.add("search_hit")
    else
      view.classList.remove("searching")

  input.addEventListener "keyup", (e) ->
    if e.which is 27 #Esc
      this.value = ""
      view.classList.remove("searching")
    return

  header.appendChild(input)

  frag = document.createDocumentFragment()
  item_list.forEach (item) ->
    a = document.createElement("a")
    a.href = app.url.safe(item.url)
    a.title = item.title
    img = document.createElement("img")
    img.src = "/img/dummy_1x1.png"
    a.appendChild(img)
    frag.appendChild(a)

    img.src = app.url.get_thumbnail_path(item.url)
    return

  view.appendChild(frag)
  view
