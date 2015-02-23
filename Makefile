all: fastbit udf

fastbit: 
	sh get_and_build_fastbit.sh "2.0.1"
	
udf: fb_udf.cpp
	g++ --std=c++11 -shared -Wl,-rpath '-Wl,$$ORIGIN' -L lib/ -I include/ -I `mysql_config --include` -l fastbit -o fb_udf.so `mysql_config --cxxflags` fb_udf.cpp

install:
	cp *.so `mysql_config --plugindir`
	cp lib/*.so* `mysql_config --plugindir`

clean:
	rm -f *.so

deep_clean:
	rm -f *.so *.gz
	rm -rf lib/ include/ bin/ fastbit-*/ share/
	
