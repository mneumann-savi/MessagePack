test:
	savi run spec

gen-spec:
	cd test-suite && ruby test-gen.rb > ../spec/MessagePack.Reader.Spec.savi

format:
	savi format

update-deps:
	savi deps update
