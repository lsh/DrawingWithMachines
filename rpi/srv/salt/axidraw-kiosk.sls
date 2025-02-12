axidraw_group:
  group.present:
    - gid: 2000
    - name: axidraw

{% for axidraw_user in pillar['axidraws'] %}
{{ axidraw_user.name }}:
{% if axidraw_user.minion == grains['id'] %}
  user.present:
    - uid: {{ 2000 + axidraw_user.id }}
    - usergroup: True
    - createhome: True
    - empty_password: True
    - allow_uid_change: True
    - allow_gid_change: True
    - remove_groups: True
    - require:
      - axidraw_group
    - groups:
        - axidraw
        - users
{% else %}
  user.absent:
    - purge: True
    - force: False
{% endif %}
{% endfor %}

udev:
  file.managed:
    - require:
        - axidraw_group
    - template: jinja
    - names:
      - /etc/udev/rules.d/99-axidraw-com.rules:
        - source: salt://axidraw-kiosk/etc/udev/rules.d/99-axidraw-com.rules
      - /etc/udev/rules.d/70-axidraw-uaccess-hid.rules:
        - source: salt://axidraw-kiosk/etc/udev/rules.d/70-axidraw-uaccess-hid.rules
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
  cmd.run:
    - name: /usr/bin/udevadm control --reload-rules
    - onchanges:
      - file: /etc/udev/rules.d/99-axidraw-com.rules
      - file: /etc/udev/rules.d/70-axidraw-uaccess-hid.rules

nfs_client:
  pkg.installed:
    - pkgs:
        - nfs-common
        - acl
        - nfs4-acl-tools

nfs_axidraw_client:
  mount.mounted:
    - require:
        - axidraw_group
        - nfs_client
    - name: /mnt/axidraw
    - device: sfci-pi1.cfa.cmu.edu:/srv/axidraw
    - fstype: nfs
    - opts: rw,user
    - dump: 0
    - pass_num: 0
    - persist: True
    - mount: True
    - mkmnt: True

#ssh:
#  pkg.installed:
#    - pkgs:
#      - openssh-server

#ssh_config:
#  file.managed:
#    - require:
#        - ssh
#    - user: root
#    - group: root
#    - mode: '0644'
#    - makedirs: True

touchscreen_xss:
  pkg.installed:
    - pkgs:
      - libxss1
  file.managed:  
    - user: root  
    - group: root   
    - mode: '0755'
    - makedirs: False
    - names:
      - /usr/local/bin/xssstart:
        {% if grains['osarch'] == 'armhf' %}
        - source: salt://axidraw-kiosk/usr/local/bin/xssstart-armhf
        {% endif %}
      - /usr/local/bin/clicklock:
        {% if grains['osarch'] == 'armhf' %}
        - source: salt://axidraw-kiosk/usr/local/bin/clicklock-armhf
        {% endif %}

login:
  pkg.installed:
    - pkgs:
      - lightdm
      - slick-greeter
      - onboard
  cmd.run:
    - name: systemctl set-default graphical.target
    - unless: test `systemctl get-default` = 'graphical.target'
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - require:
        - touchscreen_xss
    - names:
      - /etc/X11/default-display-manager:
        - source: salt://axidraw-kiosk/etc/X11/default-display-manager
      - /etc/lightdm/lightdm.conf.d/99_axidraw.conf:
        - source: salt://axidraw-kiosk/etc/lightdm/lightdm.conf.d/99_axidraw.conf
      - /etc/lightdm/slick-greeter.conf:
        - source: salt://axidraw-kiosk/etc/lightdm/slick-greeter.conf
      - /etc/X11/xorg.conf.d/99_axidraw.conf:
        - source: salt://axidraw-kiosk/etc/X11/xorg.conf.d/99_axidraw.conf

desktop:
  pkg.installed: 
    - pkgs:    
      - xfwm4
      - xfce4-panel
      - xfdesktop4
      - xfce4-session
      - xfce4-terminal
      - xfce4-appfinder
      - thunar
      - onboard
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - names:
      - /etc/xdg/xfce4/kiosk/kioskrc:
        - source: salt://axidraw-kiosk/etc/xdg/xfce4/kiosk/kioskrc
      - /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml:
        - source: salt://axidraw-kiosk/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
      - /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:
        - source: salt://axidraw-kiosk/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
      - /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml:
        - source: salt://axidraw-kiosk/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

flatpak:
  pkg.installed: 
    - pkgs:    
      - flatpak

flatpak_repo:
  cmd.run:
    - require:
       - flatpak
    - name: flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    - unless: test `flatpak remotes --system | grep 'flathub'` = 'flathub'
    - onchanges:
       - flatpak

flatpak_app_inkscape:
  cmd.run:
    - require:
        - flatpak
        - flatpak_repo
    - name: flatpak install --system --noninteractive flathub org.inkscape.Inkscape
    - unless: "test \"`flatpak info --system org.inkscape.Inkscape | grep Version`\" = '     Version: 1.0.1'"

flatpak_app_inkscape_permission:
  cmd.run:
    - require:
        - flatpak
        - flatpak_repo
        - flatpak_app_inkscape
    - name: flatpak override org.inkscape.Inkscape --device=all --system
    - unless: test `flatpak override --show --system org.inkscape.Inkscape | grep devices` = 'devices=all;'

{% if not salt['file.directory_exists' ]('/var/lib/flatpak/app/org.inkscape.Inkscape/current/active/files/share/inkscape/extensions/ad-ink_274_r1') %}
flatpak_app_inkscape_ext_axidraw:
  archive.extracted:
    - name: /var/lib/flatpak/app/org.inkscape.Inkscape/current/active/files/share/inkscape/extensions
    - source: salt://axidraw_inkscape_ext/ad-ink_274_r1.zip
#    - options: "--strip-components=1"
    - overwrite: True
    - enforce_toplevel: False
    - user: root
    - group: root
    - require:
       - flatpak_app_inkscape
{% endif %}

pip:
  pkg.installed:
    - pkgs:
      - python3-pip

pip_axidraw_requirements:
  pkg.installed:
    - pkgs:
        - libxslt1.1

python3_virtualenv:
  pkg.installed:
    - pkgs:
        - python3-venv

pip_axidraw_venv:
  cmd.run:
    - name: python3 -m venv /opt/venv-axidraw
    - unless: test -d /opt/venv-axidraw
    - require:
      - pip
      - python3_virtualenv

pip_axidraw:
  pip.installed:
   - require:
      - pip
      - pip_axidraw_requirements
      - pip_axidraw_venv
   - bin_env: /opt/venv-axidraw
   - name: https://cdn.evilmadscientist.com/dl/ad/public/AxiDraw_API.zip
   - upgrade: True
   - unless: test `/opt/venv-axidraw/bin/pip3 freeze | grep axidrawinternal` = 'axidrawinternal==2.7.4'

pip_axidraw_profile_alias:
  file.managed:
    - require:
        - pip_axidraw
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - names:
      - /etc/profile.d/99-axidraw.sh:
        - source: salt://axidraw-kiosk/etc/profile.d/99-axidraw.sh

pip_axidraw_bash_alias:
  file.blockreplace:
    - require:
        - pip_axidraw
    - name: /etc/bash.bashrc
    - marker_start: "# BEGIN SALTSTACK MANAGED BLOCK 99-axidraw -DO-NOT-EDIT-"
    - marker_end: "# END SALTSTACK BLOCK MANAGED 99-axidraw"
    - append_if_not_found: True
    - show_changes: True
    - content: |
        if [[ -z ${AXIDRAW_CONSOLE+x} ]]; then    # otherwise /etc/profile.d/* will run too
            . /etc/profile.d/99-axidraw.sh
        fi

pip_taxi_requirements:
  pkg.installed:
    - pkgs:
        - libatlas-base-dev    # For numpy
        - libsdl2-dev          # For kivy
        - libsdl2-ttf-2.0-0    # For kivy
        - libsdl2-image-2.0-0  # For kivy
        - libsdl2-mixer-2.0-0  # For kivy
        - libgeos-c1v5         # For Shapely until piwheel is fixed

pip_taxi_venv:
  cmd.run:
    - name: python3 -m venv /opt/venv-taxi
    - unless: test -d /opt/venv-taxi
    - require:
      - pip
      - python3_virtualenv

pip_taxi:
  pip.installed:
   - require:
      - pip
      - pip_taxi_requirements
      - pip_taxi_venv
      - udev
   - bin_env: /opt/venv-taxi
   - name: "https://github.com/DaAwesomeP/taxi/archive/refs/heads/main.zip#egg=taxi"
   - upgrade: True
   - unless: test `/opt/venv-taxi/bin/pip3 freeze | grep 'taxi'` = 'taxi==0.1.0a0'

pip_taxi_desktop:
  file.managed:
    - require:
        - pip_taxi
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - names:
      - /usr/share/applications/taxi.desktop:
        - source: salt://axidraw-kiosk/usr/share/applications/taxi.desktop
  cmd.run:
    - name: /usr/bin/update-desktop-database
    - onchanges:
      - file: /usr/share/applications/taxi.desktop
