# Installs nginx, writes a custom index page, keeps the service running.
package { 'nginx':
  ensure => installed,
}

file { '/var/www/html/index.html':
  ensure  => file,
  content => "<h1>Hello from Puppet on ${facts['networking']['hostname']}</h1>\n",
  require => Package['nginx'],
}

service { 'nginx':
  ensure    => running,
  enable    => true,
  require   => Package['nginx'],
  subscribe => File['/var/www/html/index.html'],
}
