all: pfork.bin sparsefile

#g++ -o pfork.bin pfork.cpp # destined for /var/spool/baracus/www/module

pfork.bin: pfork.cpp
	g++ $< -o $@

#gcc -o sparsefile sparsefile.c # destined for /usr/bin/sparsefile

sparsefile: sparsefile.c           
	gcc $< -o $@

