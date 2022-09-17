test: gen-spec
	savi run spec

gen-spec:
	cd test-suite && ruby generate.rb > ../spec/MessagePack.Reader.Spec.savi

format:
	savi format

update-deps:
	savi deps update
