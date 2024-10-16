# docker build . -t musl_docker
# bash build_hydra.sh
git clone https://github.com/vanhauser-thc/thc-hydra
cd thc-hydra && git checkout v9.5
echo "remove /usr/include in `./configure`#162 " && sed -i '162s|/usr/include||' ./configure

make clean
export CC="/usr/bin/musl-gcc -static --static"
./configure --disable-xhydra CC="/usr/bin/musl-gcc -static --static" C_INCLUDE_PATH=/usr/include/x86_64-linux-musl/
make

