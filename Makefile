# -*- mode:GNUmakefile -*-

all: README
.PHONY: all dist

exclude_options= \
	--exclude=./mcxx/local \
	--exclude=*~ \
	--exclude=./mcxx/tmp.obj \
	--exclude=./mcxx/backup \
	--exclude=./mcxx/mat \
	--exclude=./mcxx/test_cxx

# 各ディレクトリの説明
#   ./mcxx/mat        開発資料
#   ./mcxx/backup     バックアップファイル
#   ./mcxx/test_cxx   C++ コンパイラ実験

dist:
	cd .. && tar cavf mcxx.`date +%Y%m%d`.tar.xz ./mcxx $(exclude_options)

save:
	cd .. && tar cavf mcxx.`date +%Y%m%d`-save.tar.xz ./mcxx \
	  --exclude=./mcxx/local \
		--exclude=./mcxx/tmp.obj

install:
	./install.sh

README: readme.htm
	w3m -dump $< > $@

.PHONY: ext
ext: ext/echox ext/mydoc1
ext/mydoc1: $(MWGDIR)/bin/mydoc1
	cp -p $< $@
ext/echox: $(MWGDIR)/echox
	cp -p $< $@
