FIELDS = ["date", "uid", "uname", "cid", "cname", "presence", "msg", "cts", "dts", "ts"]
IXMAPS =
  presence_change: { date: 0, uid: 1, uname: 2, presence: 3 }
  user_typing: { date: 0, uid: 1, uname: 2, cid: 3, cname: 4 }
  bot_message: { date: 0, uname: 1, cid: 2, cname: 3, msg: 4, ts: 5 }
  message_changed: { date: 0, uid: 1, uname: 2, cid: 3, cname: 4, msg: 5, cts: 6, ts: 7 }
  message_deleted: { date: 0, cid: 1, cname: 2, dts: 3, ts: 4 }
  message: { date: 0, uid: 1, uname: 2, cid: 3, cname: 4, msg: 5, ts: 6 }

$ = (id) -> document.getElementById(id)

init_datetimepicker = (id, h, m, s, ms) ->
  elem = $(id)
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

filters_row = $("filters")
results_table = $("results")
filter_inputs = {}
result_rows = []

apply_filters = ->
  filters = {}
  for field, input of filter_inputs
    filters[field] = input.value
  zebra = true
  for row in result_rows
    match = true
    for field, i in FIELDS
      if row.children[i].textContent.indexOf(filters[field]) == -1
        match = false
    row.className = if match && zebra then "results-row" else "results-row zebra"
    row.style.display = if match then "table-row" else "none"
    zebra = !zebra if match
  return

for field in FIELDS
  filters_row.insertAdjacentHTML "beforeend",
    """<td class="#{field}"><input id="#{field}-filter" size="16" placeholder="no filter"></td>"""
  filter_input = $("#{field}-filter")
  filter_input.oninput = apply_filters
  filter_inputs[field] = filter_input

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

window.show_logs = ->
  from = new Date($("from").value).getTime()
  to = new Date($("to").value).getTime()
  pw = $("pw").value
  url = "http://logservice-codechan.rhcloud.com/messages?from=#{from}&to=#{to}&pw=#{pw}"
  xhr = new XMLHttpRequest()
  xhr.onreadystatechange = ->
    return if xhr.readyState != 4
    switch xhr.status
      when 403
        alert("Access denied!")
      when 200
        for row in result_rows
          row.parentNode.removeChild(row)
        result_rows = []
        entries = JSON.parse(xhr.responseText)
        for i in [0...entries.length] by 2
          msg_data = JSON.parse(entries[i])
          msg_type = msg_data[0]
          msg_data[0] = format_date(new Date(parseInt(entries[i+1])))
          row = render_row(msg_type, msg_data)
          results_table.appendChild(row)
          result_rows.push(row)
        apply_filters()
      else
        alert("Unknown status: #{xhr.status}")
  xhr.open("GET", url, false)
  xhr.send()
