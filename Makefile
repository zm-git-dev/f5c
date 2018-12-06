CC       = gcc
CXX      = g++
CFLAGS   += -g -rdynamic -Wall -O2 -std=c++11 

-include config.mk

LDFLAGS += $(LIBS) -lpthread -lz
BUILD_DIR = build

# SRC = src/main.c src/meth_main.c src/f5c.c src/events.c src/nanopolish_read_db.c \
#       src/nanopolish_index.c src/model.c src/align.c src/meth.c src/hmm.c
OBJ = $(BUILD_DIR)/main.o $(BUILD_DIR)/meth_main.o $(BUILD_DIR)/f5c.o $(BUILD_DIR)/events.o $(BUILD_DIR)/nanopolish_read_db.o \
      $(BUILD_DIR)/nanopolish_index.o $(BUILD_DIR)/model.o $(BUILD_DIR)/align.o $(BUILD_DIR)/meth.o $(BUILD_DIR)/hmm.o
BINARY = f5c
DEPS = src/config.h  src/error.h  src/f5c.h  src/f5cmisc.h  src/fast5lite.h  src/logsum.h  \
       src/matrix.h  src/model.h  src/nanopolish_read_db.h src/ksort.h

ifdef cuda
    DEPS_CUDA = src/f5c.h src/fast5lite.h src/error.h src/f5cmisc.cuh
    #SRC_CUDA = f5c.cu align.cu 
    OBJ_CUDA = $(BUILD_DIR)/f5c_cuda.o $(BUILD_DIR)/align_cuda.o
    CC_CUDA = nvcc
    CFLAGS_CUDA += -g  -O2 -std=c++11 -lineinfo $(CUDA_ARCH)
	CUDALIB += -L/usr/local/cuda/lib64/ -lcudart -lcudadevrt
    #CUDALIB_STATIC += -L/usr/local/cuda/lib64/ -lcudart_static -lcudadevrt -lrt
    OBJ += $(BUILD_DIR)/gpucode.o $(OBJ_CUDA)
    CPPFLAGS += -DHAVE_CUDA=1
endif


HDF5 ?= install
HTS ?= install

HTS_VERSION = 1.9
HDF5_VERSION = 1.10.4

ifdef ENABLE_PROFILE
    CFLAGS += -p
endif

ifeq ($(HDF5), install)
    HDF5_LIB = $(BUILD_DIR)/lib/libhdf5.a
    HDF5_INC = -I$(BUILD_DIR)/include
    LDFLAGS += $(HDF5_LIB) -ldl
else
ifneq ($(HDF5), autoconf)
    HDF5_LIB =
    HDF5_SYS_LIB = $(shell pkg-config --libs hdf5)
    HDF5_INC = $(shell pkg-config --cflags-only-I hdf5)
endif
endif

ifeq ($(HTS), install)
    HTS_LIB = $(BUILD_DIR)/lib/libhts.a
    HTS_INC = -I$(BUILD_DIR)/include
	LDFLAGS += $(HTS_LIB)
else
ifneq ($(HTS), autoconf)
    HTS_LIB =
    HTS_SYS_LIB = $(shell pkg-config --libs htslib)
    HTS_INC = $(shell pkg-config --cflags-only-I htslib)
endif	
endif

CPPFLAGS += $(HDF5_INC) $(HTS_INC)
LDFLAGS += $(HTS_SYS_LIB) $(HDF5_SYS_LIB)


.PHONY: clean distclean format test


$(BINARY): $(HTS_LIB) $(HDF5_LIB) $(OBJ)
	$(CXX) $(CFLAGS) $(OBJ) $(LDFLAGS) $(CUDALIB) -o $@

$(BUILD_DIR)/main.o: src/main.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/meth_main.o: src/meth_main.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/f5c.o: src/f5c.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/events.o: src/events.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/nanopolish_read_db.o: src/nanopolish_read_db.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/nanopolish_index.o: src/nanopolish_index.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/model.o: src/model.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/align.o: src/align.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/meth.o : src/meth.c $(DEPS)
	$(CXX) $(CFLAGS)$(CPPFLAGS) $< -c -o $@

$(BUILD_DIR)/hmm.o: src/hmm.c $(DEPS)
	$(CXX) $(CFLAGS) $(CPPFLAGS) $< -c -o $@


#cuda stuff

$(BUILD_DIR)/gpucode.o : $(OBJ_CUDA)
	$(CC_CUDA) $(CFLAGS_CUDA) -dlink $^ -o $@ 

$(BUILD_DIR)/f5c_cuda.o : src/f5c.cu $(DEPS_CUDA)
		$(CC_CUDA) -x cu $(CFLAGS_CUDA) $(CPPFLAGS)  -rdc=true -c $< -o $@

$(BUILD_DIR)/align_cuda.o : src/align.cu $(DEPS_CUDA)
		$(CC_CUDA) -x cu $(CFLAGS_CUDA) $(CPPFLAGS)  -rdc=true -c $< -o $@





config.h:
	echo "/* Default config.h generated by Makefile */" >> $@
	echo "#define HAVE_HDF5_H 1" >> $@

$(BUILD_DIR)/lib/libhts.a:
	@mkdir -p $(BUILD_DIR)
	@if command -v curl; then \
		curl -o $(BUILD_DIR)/htslib.tar.bz2 -L https://github.com/samtools/htslib/releases/download/$(HTS_VERSION)/htslib-$(HTS_VERSION).tar.bz2; \
	else \
		wget -O $(BUILD_DIR)/htslib.tar.bz2 https://github.com/samtools/htslib/releases/download/$(HTS_VERSION)/htslib-$(HTS_VERSION).tar.bz2; \
	fi
	tar -xf $(BUILD_DIR)/htslib.tar.bz2 -C $(BUILD_DIR)
	mv $(BUILD_DIR)/htslib-$(HTS_VERSION) $(BUILD_DIR)/htslib
	$(RM) $(BUILD_DIR)/htslib.tar.bz2
	cd $(BUILD_DIR)/htslib && \
	./configure --prefix=`pwd`/$(BUILD_DIR) --enable-bz2=no --enable-lzma=no --with-libdeflate=no --enable-libcurl=no  --enable-gcs=no --enable-s3=no && \
	make -j8 && \
	make install

$(BUILD_DIR)/lib/libhdf5.a:
	@mkdir -p $(BUILD_DIR) 
	@if command -v curl; then \
		curl -o $(BUILD_DIR)/hdf5.tar.bz2 https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-$(shell echo $(HDF5_VERSION) | awk -F. '{print $$1"."$$2}')/hdf5-$(HDF5_VERSION)/src/hdf5-$(HDF5_VERSION).tar.bz2; \
	else \
		wget -O $(BUILD_DIR)/hdf5.tar.bz2 https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-$(shell echo $(HDF5_VERSION) | awk -F. '{print $$1"."$$2}')/hdf5-$(HDF5_VERSION)/src/hdf5-$(HDF5_VERSION).tar.bz2; \
	fi
	tar -xf $(BUILD_DIR)/hdf5.tar.bz2 -C $(BUILD_DIR)
	mv $(BUILD_DIR)/hdf5-$(HDF5_VERSION) $(BUILD_DIR)/hdf5
	$(RM) $(BUILD_DIR)/hdf5.tar.bz2
	cd $(BUILD_DIR)/hdf5 && \
	./configure --prefix=`pwd`/$(BUILD_DIR) && \
	make -j8 && \
	make install

clean: 
	$(RM) -r $(BINARY) $(BUILD_DIR)/*.o

# Delete all gitignored files (but not directories)
distclean: clean
	git clean -f -X 
	$(RM) -r ./autom4te.cache $(BUILD_DIR)


test: $(BINARY)
	./scripts/test.sh
