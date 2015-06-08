requires "CPAN::Meta" => "2.142690";
requires "CPAN::Uploader" => "0.103004";
requires "Class::Null" => "2.101420";
requires "Class::Usul" => "v0.63.0";
requires "Config::Tiny" => "2.20";
requires "Date::Format" => "2.24";
requires "Dist::Zilla" => "4.300033";
requires "Dist::Zilla::Plugin::AbstractFromPOD" => "v0.2.0";
requires "Dist::Zilla::Plugin::LicenseFromModule" => "0.03";
requires "Dist::Zilla::Plugin::ManifestInRoot" => "v0.1.0";
requires "Dist::Zilla::Plugin::Meta::Dynamic::Config" => "0.04";
requires "Dist::Zilla::Plugin::ModuleBuild::Custom" => "4.16";
requires "Dist::Zilla::Plugin::ReadmeAnyFromPod" => "0.141760";
requires "Dist::Zilla::Plugin::Signature" => "1.100930";
requires "Dist::Zilla::Plugin::VersionFromModule" => "0.08";
requires "File::DataClass" => "v0.62.0";
requires "File::ShareDir" => "1.102";
requires "HTTP::Message" => "6.06";
requires "LWP" => "6.08";
requires "LWP::Protocol::https" => "6.03";
requires "Module::Install" => "1.12";
requires "Module::Install::AutoLicense" => "0.08";
requires "Module::Install::ReadmeFromPod" => "0.20";
requires "Module::Install::ReadmeMarkdownFromPod" => "0.03";
requires "Module::Metadata" => "1.000011";
requires "Moo" => "2.000001";
requires "Perl::Version" => "1.013";
requires "Pod::Eventual" => "0.094001";
requires "Software::License" => "0.103010";
requires "Template" => "2.26";
requires "Test::Requires" => "0.08";
requires "Try::Tiny" => "0.22";
requires "Type::Tiny" => "1.000004";
requires "Unexpected" => "v0.38.0";
requires "local::lib" => "2.000014";
requires "namespace::autoclean" => "0.22";
requires "perl" => "5.010001";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "Test::Requires" => "0.08";
  requires "version" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
