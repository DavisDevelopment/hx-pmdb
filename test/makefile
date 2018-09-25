
default: build-dtt run-js

all: build-all run-all

build-all: build-dtt build-stt

build-dtt:
	haxe build.hxml
	
build-stt:
	haxe build-stt.hxml

run-all: run-js run-py run-neko run-hashlink

run-js:
	# JavaScript (NodeJS)
	cd ../build/js && node test.js

run-py:
	# Python
	cd ../build/py && python3 test.py

run-neko:
	# NekoVm
	cd ../build/neko && neko test.n

run-hashlink:
	# HashLink Vm
	cd ../build/hashlink && hl test.hl

