# template-project-docs

Provides documentation for a project. See `src/docs/asciidoc/index.adoc`

## Getting started

### Generating documentation

The source Asciidoc files are located in `src/docs/asciidoc`. In order to generate html and pdf versions
of the content, run the following:

`./gradlew` 

This runs the default task `asciidoctor` to generate the html content in the `build/` directory.

### Working with Asciidoc

Authoring Asciidoc is similar to working with Markdown. However, Asciidoc provides macros and metadata
structures that allow for richer content. The following cheat sheets provide details on the different
elements that can be used:

- https://asciidoctor.org/docs/asciidoc-syntax-quick-reference/
- https://powerman.name/doc/asciidoc

## What's provided

### Package json

A package.json file is provided to document the name of the project and manage the version numbers. It
is also a convenient spot to document the scripts provided by the repository.

### Asciidoc skeleton

The following skeleton files exist in `src/docs/asciidoc`:

- index.adoc
- _sample-include.adoc
- images/sunset.jpg

Additional files can be added into this structure as appropriate.

### Gradle config

Gradle is provided (build.gradle and gradle wrapper) to generate html and pdf output from asciidoc content.
Instructions for how to work with Gradle are provided below.

### Jenkins pipeline config

A Jenkins pipeline configuration file (`Jenkinsfile`) is provided to allow this content to be built and published
in an automated Jenkins process. It has been written to depend on the Jenkins kubernetes plugin.

### Docker config

A Docker config file (`Dockerfile`) has been provided to package the generated content into a container that
can run in a containerized environment.

### Helm chart

A helm chart (`chart/template-project-docs`) is provided to deploy the container into a Kubernetes or OpenShift cluster.
