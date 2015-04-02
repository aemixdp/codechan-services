FIELDS = ["date", "uname", "cname", "presence", "msg", "cts", "dts", "ts"]
IXMAPS =
  presence_change: { date: 0, uid: 1, uname: 2, presence: 3 }
  user_typing: { date: 0, uid: 1, uname: 2, cid: 3, cname: 4 }
  bot_message: { date: 0, uname: 1, cid: 2, cname: 3, msg: 4, ts: 5 }
  message_changed: { date: 0, uid: 1, uname: 2, cid: 3, cname: 4, msg: 5, cts: 6, ts: 7 }
  message_deleted: { date: 0, cid: 1, cname: 2, dts: 3, ts: 4 }
  message: { date: 0, uid: 1, uname: 2, cid: 3, cname: 4, msg: 5, ts: 6 }

init_datetimepicker = (id, h, m, s, ms) ->
  elem = document.getElementById(id)
  new Pikaday
    field: elem,
    firstDay: 1,
    minDate: new Date('2015-03-30'),
    maxDate: new Date('2020-12-31'),
    yearRange: [2015, 2020],
    showTime: true,
    use24hour: true
  date = new Date()
  date.setHours(h, m, s, ms)
  elem.value = date

init_datetimepicker("from", 0, 0, 0, 0)
init_datetimepicker("to", 23, 59, 59, 999)

filters_row = document.getElementById("filters")
results_table = document.getElementById("results")
pages_list = document.getElementById("pages")

filter_inputs = {}
result_rows = []
filtered_rows = []
pages = {}

apply_filters = ->
  filters = {}
  for field, input of filter_inputs
    filters[field] = input.value
  filtered_rows = result_rows.filter (row) ->
    for field, i in FIELDS
      if row.children[i].textContent.indexOf(filters[field]) == -1
        return false
    return true

paginate = ->
  pages = {}
  count = Math.floor(filtered_rows.length / 50)
  while li = pages_list.lastChild
    pages_list.removeChild(li)
  for i in [0..count]
    offset = i * 50
    pages[i] = filtered_rows.slice(offset, offset + 50)
    li = document.createElement("li")
    a = document.createElement('a')
    a.id = "page-#{i}"
    a.href = '#'
    a.onclick = -> select_page(parseInt(@textContent))
    a.textContent = i
    a.className = "selected" if i == 0
    li.appendChild(a)
    pages_list.appendChild(li)

select_page = (i) ->
  fragment = document.createDocumentFragment()
  for tr in pages[i]
    fragment.appendChild(tr)
  for row in document.querySelectorAll(".results-row")
    row.parentNode.removeChild(row)
  results_table.appendChild(fragment)
  document.querySelector(".selected").className = ""
  document.getElementById("page-#{i}").className = "selected"

refresh = ->
  apply_filters()
  paginate()
  select_page(0)

render_row = (msg_type, msg_data) ->
  ixmap = IXMAPS[msg_type]
  render_cell = (field) ->
    td = document.createElement("td")
    td.className = field
    td.appendChild(document.createTextNode(msg_data[ixmap[field]] || '-'))
    return td
  tr = document.createElement("tr")
  tr.className = "results-row"
  for field in FIELDS
    tr.appendChild(render_cell(field))
  return tr

format_date = (date) ->
  "#{date.getUTCDate()}.#{date.getUTCMonth() + 1}.#{date.getUTCFullYear()} " +
  date.toLocaleTimeString()

window.show_period_log = ->
  from = new Date(document.getElementById("from").value).getTime()
  to = new Date(document.getElementById("to").value).getTime()
  pw = document.getElementById("pw").value
  url = "http://logservice-codechan.rhcloud.com/messages?from=#{from}&to=#{to}&pw=#{pw}"
  xhr = new XMLHttpRequest()
  xhr.onreadystatechange = ->
    return if xhr.readyState != 4
    switch xhr.status
      when 403
        alert("Access denied!")
      when 200
        result_rows = []
        entries = JSON.parse(xhr.responseText)
        for i in [0...entries.length] by 2
          msg_data = JSON.parse(entries[i])
          msg_type = msg_data[0]
          msg_data[0] = format_date(new Date(parseInt(entries[i+1])))
          row = render_row(msg_type, msg_data)
          results_table.appendChild(row)
          result_rows.push(row)
        refresh()
      else
        alert("Unknown status: #{xhr.status}")
  xhr.open("GET", url, false)
  xhr.send()

window.download_full_log = ->
  pw = document.getElementById("pw").value
  url = "http://logservice-codechan.rhcloud.com/fulldump?pw=#{pw}"
  document.location = url

for field in FIELDS
  filters_row.insertAdjacentHTML "beforeend",
    """<td class="#{field}"><input id="#{field}-filter" size="16" placeholder="no filter"></td>"""
  filter_input = document.getElementById("#{field}-filter")
  filter_input.oninput = refresh
  filter_inputs[field] = filter_input