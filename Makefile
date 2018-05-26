SOURCEFILES =	drdt.d \
		encoding.d \
		radiodata.d \
		radiodatafile.d \
		radiosettings.d 

all:	drdt

drdt:	$(SOURCEFILES)
	dmd -of=drdt $(SOURCEFILES)
