=comment

Install all dependencies with:

    cpanm --installdeps . --with-develop --with-all-features

Note on version specification syntax:

    # Any version of My::Module equal or higher than 0.01 is required
    requires 'My::Module' => '0.01';

    # ditto
    requires 'My::Module' => '>= 0.01';

    # Exactly My::Module v0.01 is required
    requires 'My::Module' => '== 0.01';

See https://metacpan.org/pod/CPAN::Meta::Spec#VERSION-NUMBERS for details.

=cut

requires 'perl', '5.24.0';
requires 'strictures';
requires 'List::MoreUtils::XS';
requires 'Term::UI';
requires 'Math::Trig';
requires 'Scalar::Util::Numeric';
requires 'Moose';
requires 'MooseX::MarkAsMethods','0.13';
requires 'MooseX::NonMoose','0.25';

on 'develop' => sub {
    requires 'App::Ack';
    requires 'Pod::Cpandoc';
    requires 'Devel::NYTProf';
    requires 'Perl::Tidy';
    requires 'Perl::Critic';
    requires 'Perl::Critic::Policy::Miscellanea::RequireRcsKeywords';
    requires 'Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseSubs';
    requires 'Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseVars';
};

on 'test' => sub {
    requires 'Test::More';
    requires 'Test::Most';
    requires 'Perl::Critic';
    requires 'Perl::Critic::Policy::Miscellanea::RequireRcsKeywords';
    requires 'Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseSubs';
    requires 'Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseVars';
    requires 'Test::Perl::Critic';
};
