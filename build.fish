#!/usr/bin/env fish

set remote_path s3://jonnystoten-arch/repo/x86_64
set local_path $HOME/.local/share/arch-repo
set repo_name jonnystoten

set packages $argv
if test -z $packages
  set packages pkg/*
end

set chroot $PWD/chroot

mkdir -p $local_path
mkdir -p $chroot

if not test -d $chroot/root
  mkarchroot -C /etc/pacman.conf $chroot/root base base-devel
end

# Sync remote db to local
s3cmd sync $remote_path/$repo_name.{db,files}.tar.xz $local_path/
ln -sf $repo_name.db.tar.xz $local_path/$repo_name.db
ln -sf $repo_name.files.tar.xz $local_path/$repo_name.files

# Clean up older packages
set old_packages $local_path/*.pkg.tar.xz
rm -f $old_packages

for package in $packages
  pushd $package
  rm -f *.pkg.tar.xz
  makechrootpkg -cur $chroot
  popd
end

# Sync local db to remote
s3cmd sync --follow-symlinks --acl-public \
  $packages/*.pkg.tar.xz \
  $local_path/$repo_name.{db,files}{,.tar.xz} \
  $remote_path/
