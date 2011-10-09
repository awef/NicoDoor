SRC = src
DBG = build

haml = haml -q $(1) $(2)
sass = sass --style compressed --no-cache $(1) $(2)
coffee = cat $(1) | coffee -cbsp | uglifyjs -o $(2)
svg = convert\
  -background transparent\
  -resize $(2)x$(3)\
  ${SRC}/svg/$(1).svg ${DBG}/img/$(1)_$(2)x$(3).png

.PHONY: all
all:\
	${DBG}\
	${DBG}/manifest.json\
	${DBG}/app.html\
	${DBG}/app.js\
	${DBG}/app.css\
	${DBG}/img/

.PHONY: clean
clean:
	rm -rf ${DBG}

${DBG}:
	mkdir ${DBG}

${DBG}/manifest.json: ${SRC}/manifest.json
	cp ${SRC}/manifest.json ${DBG}/manifest.json

${DBG}/app.html: ${SRC}/app.haml
	$(call haml, ${SRC}/app.haml, ${DBG}/app.html)

${DBG}/app.js:\
  ${SRC}/app.coffee\
  ${SRC}/app.*.coffee
	$(call coffee,\
    ${SRC}/app.coffee\
    ${SRC}/app.*.coffee\
    , ${DBG}/app.js)

${DBG}/app.css: ${SRC}/app.sass
	$(call sass, ${SRC}/app.sass, ${DBG}/app.css)

${DBG}/img/: ${SRC}/svg/*.svg
	rm -rf ${DBG}/img/
	mkdir ${DBG}/img/
	$(call svg,dummy,1,1)
	$(call svg,nicodoor,128,128)
