{ assert, brains, Browser } = require("./helpers")


JQUERY_VERSIONS = ["1.4.4", "1.5.1", "1.6.3", "1.7.1", "1.8.0"]


describe "Compatibility with jQuery", ->

  browser = null
  before (done)->
    browser = Browser.create()
    brains.ready(done)

  for version in JQUERY_VERSIONS
    do (version)->
      describe version, ->

        before ->
          brains.get "/compat/jquery-#{version}", (req, res)->
            res.send """
            <html>
              <head>
                <title>jQuery #{version}</title>
                <script src="/jquery-#{version}.js"></script>
              </head>
              <body>
                <select>
                  <option>None</option>
                  <option value="1">One</option>
                </select>

                <span id="option"></span>

                <a href="#post">Post</a>

                <div id="response"></div>

                <input id="edit-subject" value="Subject">
                <textarea id="edit-note">Note</textarea>

                <form action="/zombie/dead-end">
                  <button class="some-class">Click Me</button>
                </form>
              </body>

              <script>
                $(function() {

                  $("select").bind("change", function() {
                    $("#option").text(this.value);
                  });

                  $("a[href='#post']").click(function() {
                    $.post("/compat/echo/jquery-#{version}", {"foo": "bar"}, function(response) {
                      $("#response").text(response);
                    });

                    return false;
                  });
                });
              </script>
            </html>
            """

          brains.post "/compat/echo/jquery-#{version}", (req, res)->
            lines = ([key, value].join("=") for key, value of req.body)
            res.send lines.join("\n")


        before (done)->
          browser.visit("http://localhost:3003/compat/jquery-#{version}", done)


        describe "selecting an option in a select element", ->
          before ->
            browser.select("select", "1")

          it "should fire the change event", ->
            browser.assert.text "#option", "1"


        describe "jQuery.post", ->
          before (done)->
            browser.clickLink("Post", done)

          it "should perform an AJAX POST request", ->
            browser.assert.text "#response", /foo=bar/


        describe "jQuery.globalEval", ->
          before ->
            browser.evaluate("(function () {
              $.globalEval('var globalEvalWorks = true;');
            })();")

          it "should work as expected", ->
            browser.assert.global "globalEvalWorks", true


        describe "setting val to empty", ->
          it "should set to empty", ->
            browser.assert.input "#edit-subject", "Subject"
            browser.window.$("input#edit-subject").val("")
            browser.assert.input "#edit-subject", ""

            browser.assert.input "#edit-note", "Note"
            browser.window.$("textarea#edit-note").val("")
            browser.assert.input "#edit-note", ""


        # See issue 235 https://github.com/assaf/zombie/issues/235
        if version > "1.6"
          describe "undefined attribute", ->
            it "should return undefined", ->
              assert.equal browser.window.$("#response").attr("class"), undefined

          describe "closest with attribute selector", ->
            it "should find element", ->
              browser.window.$("#response").html("<div class='ok'>")
              assert.equal browser.window.$("#response .ok").closest("[id]").attr("id"), "response"


        # Using new event delegation introduced in 1.7
        if version > "1.7"

          describe "event handling", ->
            it "should catch live event handler", (done)->
              browser.visit "http://localhost:3003/compat/jquery-#{version}", ->
                browser.window.$(browser.document).live "click", ".some-class", (event)->
                  done()
                browser.pressButton "Click Me"

            it "should respect preventDefault in event delegation", (done)->
              browser.visit("http://localhost:3003/compat/jquery-#{version}")
                .then ->
                  browser.window.$(browser.document).on "click", ".some-class", (event)->
                    event.preventDefault()
                    return
                  browser.pressButton "Click Me"
                .then ->
                  assert browser.location.pathname != "/zombie/dead-end"
                .then(done, done)

  after ->
    browser.destroy()
