#!/usr/bin/perl
use strict;
use warnings;
use File::Path qw(make_path);
use Cwd;

#solution config
my $solution_name = "EmptySolution";

#config of projects and classes

my %projects = (
    "domain" => {
        type => "classlib",
        namespace => "domain",
        class_dirs => {
            "Entity" => ["Entity"],
            "Repository" => ["IRepository"],
            "ValueObject" => ["ValueObject"]
        }
    },
    "data" => {
        type => "classlib",
        namespace => "data",
        class_dirs => {
            "DBConfig" => ["ApplicationContext", "DesignTimeDbContextFactory"],
            "Repository" => ["Repository"]
        }
    },
    "IoC" => {
        type => "classlib",
        namespace => "IoC",
        class_dirs => {
            "" => ["Bootstrapper"],
        }
    },
    "application" => {
        type => "classlib",
        namespace => "application",
        class_dirs => {
            "AutoMapper" => ["ModelMapping"],
            "Services" => ["Service", "IService"]
        }
    },
    "CrossCutting" => {
        type => "classlib",
        namespace => "CrossCutting",
        class_dirs => {
            "Constants" => ["Constants"],
            "Dto" => ["Dto"],
            "Validation" => ["Validation"]
        }
    },
    "Api" => {
        type => "webapi",
        namespace => "Api",
        class_dirs => {}
    }
);

# --- Test projects ---
my %test_projects = (
    "tests" => {
        type => "xunit",
        namespace => "Tests",
        target_refs => []
    }
);

my $base_dir = getcwd();
my $root_project = "$base_dir/standard-project";
mkdir $root_project unless -d $root_project;

my $src_dir = "$root_project/src";
mkdir $src_dir unless -d $src_dir;

my $tests_dir = "$root_project/tests";
mkdir $tests_dir unless -d $tests_dir;

my $solution_sln = "$src_dir/$solution_name.sln";

# 1. Create solution
print "\nCreating solution $solution_name...\n";
system("dotnet new sln -n $solution_name --output $src_dir") == 0
    or die "Error creating solution: $!";

# 2. Create projects and add to solution
foreach my $project (keys %projects) {
    my $proj_path = "$src_dir/$project";

    my $type = $projects{$project}{type};
    my $cmd_type = $type eq "webapi" ? "webapi" : "classlib";

    print "Creating $type project: $project...\n";
    my $framework = "--framework net8.0";
    system("dotnet new $cmd_type -n $project $framework --output $proj_path") == 0
        or die "Error creating $project: $!";

    # Add to solution
    system("dotnet sln $src_dir/$solution_name.sln add $proj_path/$project.csproj") == 0
        or die "Error adding $project to solution: $!";

    if ($type eq "classlib") {
        my $namespace = $projects{$project}{namespace};
        my $dirs_ref  = $projects{$project}{class_dirs};

        foreach my $subdir (keys %$dirs_ref) {
            my $dir_path = $subdir ? "$proj_path/$subdir" : $proj_path;
            make_path($dir_path);

            foreach my $class (@{$dirs_ref->{$subdir}}) {
                my $file_path = "$dir_path/$class.cs";
                open(my $fh, ">", $file_path) or die "Can't create $file_path: $!";

                my $full_namespace = $subdir
                    ? "$namespace.$subdir"
                    : $namespace;

                print $fh <<"END_CLASS";
namespace $full_namespace
{
    public class $class
    {
        public void Hello()
        {
            
        }
    }
}
END_CLASS
                close($fh);
                print "Created class $class in $file_path\n";
            }
        }
    }
}

# 3. Add references

my %refs = (
    "application"  => ["domain"],
    "infra"        => ["domain"],
    "ioc"          => ["application", "infra", "domain"],
    "Api"          => ["application", "domain", "infra", "ioc", "CrossCutting"],
);

foreach my $proj (keys %refs) {
    foreach my $ref (@{$refs{$proj}}) {
        my $from = "$src_dir/$proj/$proj.csproj";
        my $to   = "$src_dir/$ref/$ref.csproj";

        if (-f $from && -f $to) {
            print "Adding reference: $proj -> $ref\n";
            system("dotnet add $from reference $to") == 0
                or die "Error referencing $ref in $proj: $!";
        }
    }
}

foreach my $project (keys %test_projects) {
    my $proj_path = "$tests_dir/$project";

    print "Creating xUnit test project: $project...\n";
    system(
        "dotnet", "new", "xunit",
        "-n", $project,
        "--output", $proj_path,
        "-f", "net8.0"
    ) == 0 or die "Error creating test project $project: $!";

    system(
        "dotnet", "sln",
        $solution_sln,
        "add",
        "$proj_path/$project.csproj"
    ) == 0 or die "Error adding test project $project to solution: $!";
}


# 4. Build
print "\nBuilding solution...\n";
system("dotnet build $src_dir/$solution_name.sln") == 0
    or die "Error building solution: $!";

print "\n✅ Solution with Web API and class libraries created and built successfully!\n";