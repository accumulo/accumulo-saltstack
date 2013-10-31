hadoop:
  group.present:
    - gid: {{ pillar.get('hadoop_gid', '6000') }}
  file.directory:
    - user: root
    - group: hadoop
    - mode: 775
    - names:
      - /var/log/hadoop
      - /var/run/hadoop
      - /var/lib/hadoop

{% set hadoop_users = {'hdfs':'6001','mapred':'6002','yarn':'6003'} %}

{% for username, default_uid in hadoop_users.items() %}
{% set uid = pillar.get(username+'_uid', default_uid) %}
{% set userhome = '/home/' + username %}

{{ username }}:
  group.present:
    - gid: {{ uid }}
  user.present:
    - uid: {{ uid }}
    - gid: {{ uid }}
    - home: {{ userhome }}
    - groups: ['hadoop']
    - require:
      - group: hadoop
      - group: {{ username }}
  file.directory:
    - user: {{ username }}
    - group: hadoop
    - names:
      - /var/log/hadoop/{{ username }}
      - /var/run/hadoop/{{ username }}
      - /var/lib/hadoop/{{ username }}
    - require:
      - file.directory: /var/lib/hadoop
      - file.directory: /var/run/hadoop
      - file.directory: /var/log/hadoop

{{ userhome }}/.ssh:
  file.directory:
    - user: {{ username }}
    - group: {{ username }}
    - mode: 744
    - require:
      - user: {{ username }}
      - group: {{ username }}

{{ username }}_private_key:
  file.managed:
    - name: {{ userhome }}/.ssh/id_dsa
    - user: {{ username }}
    - group: {{ username }}
    - mode: 600
    - source: salt://hadoop/files/dsa-{{ username }}
    - require:
      - file.directory: {{ userhome }}/.ssh

{{ username }}_public_key:
  file.managed:
    - name: {{ userhome }}/.ssh/id_dsa.pub
    - user: {{ username }}
    - group: {{ username }}
    - mode: 644
    - source: salt://hadoop/files/dsa-{{ username }}.pub
    - require:
      - file.managed: {{ username }}_private_key

ssh_dss_{{ username }}:
  ssh_auth.present:
    - user: {{ username }}
    - source: salt://hadoop/files/dsa-{{ username }}.pub
    - require:
      - file.managed: {{ username }}_private_key

{{ userhome }}/.ssh/config:
  file.managed:
    - source: salt://misc/ssh_config
    - user: {{ username }}
    - group: {{ username }}
    - mode: 644
    - require:
      - file.directory: {{ userhome }}/.ssh

{{ userhome }}/.bashrc:
  file.append:
    - text:
      - export PATH=$PATH:/usr/lib/hadoop/bin:/usr/lib/hadoop/sbin

{% endfor %}

{% for dir in pillar['hdfs_directories'] %}
{{ dir }}:
  file.directory:
    - user: root
    - group: root
    - makedirs: True
{% endfor %}

{% for dir in pillar['mapred_local_directories'] %}
{{ dir }}:
  file.directory:
    - user: mapred
    - group: hadoop
    - mode: 755
    - makedirs: True
    - require:
      - user: mapred
{% endfor %}

/etc/hadoop:
  file.directory:
    - user: root
    - group: root
    - mode: 755

/etc/security/limits.d/99-hadoop.conf:
  file.managed:
    - source: salt://hadoop/files/99-hadoop.conf.jinja
    - template: jinja
