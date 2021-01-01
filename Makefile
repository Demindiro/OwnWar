NAME?=ownwar
OUTPUT?=./bin/
INSTALL?=/usr/local/bin/
PLATFORM?=Linux/X11
GODOT?=godot
CP?=cp


default: build


build: $(OUTPUT)
	$(GODOT) --no-window --export "$(PLATFORM)" "$(OUTPUT)/$(NAME)"


build-debug: $(OUTPUT)
	$(GODOT) --no-window --export-debug "$(PLATFORM)" "$(OUTPUT)/$(NAME)"


install:
	$(CP) "$(OUTPUT)/$(NAME)" "$(INSTALL)"
	$(CP) "$(OUTPUT)/$(NAME).pck" "$(INSTALL)"


clean:
	rm -r $(OUTPUT)


editor:
	$(GODOT) --editor


$(OUTPUT):
	mkdir -p $(OUTPUT)
