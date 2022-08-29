pushd ..
docker run --rm -it -u `id -u`:`id -g` -v $PWD:/pisces -w /pisces pisces
popd