test:
	savi run spec 2>&1 | wc -l

gen-spec:
	cd test-suite && ruby generator.rb > ../spec/MessagePack.Reader.Spec.savi

format:
	savi format

update-deps:
	savi deps update
