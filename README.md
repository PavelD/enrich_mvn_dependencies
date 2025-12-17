# Enrich Maven Dependencies

When using the `maven-dependency-plugin` to detect unused declared dependencies or used but undeclared dependencies in a Maven project, the original source (i.e., the parent or transitive dependency that brings it in) is lost.  

This script enhances the analysis by showing **all parent dependencies** for each used undeclared dependency, making it easier to understand **why a dependency is present** in your project.

---

## Features

- Extracts `Used undeclared dependencies` from Maven `dependency:analyze`
- Maps them to the **parent chain** using Maven `dependency:tree`
- Preserves all other sections (`Unused declared dependencies`, `Non-test scoped test-only dependencies`) unchanged
- Works for **multi-module Maven projects**
- Outputs enriched information directly to **stdout**

---

## Example Maven Configuration

Here’s a typical `maven-dependency-plugin` setup for a multi-module project:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-dependency-plugin</artifactId>
    <version>3.9.0</version>
    <executions>
        <execution>
            <id>analyze-dependencies</id>
            <goals>
                <goal>analyze</goal>
            </goals>
            <configuration>
                <!-- usual place for Spring/Hibernate false-positives -->
                <ignoredDependencies>
                    <ignoredDependency>com.example:ignore</ignoredDependency>
                </ignoredDependencies>
                <ignoreNonCompile>true</ignoreNonCompile>
                <failOnWarning>false</failOnWarning>
            </configuration>
        </execution>
    </executions>
</plugin>
```

## Usage

Run the script from the **root of the Maven project**:

```bash
bash enrich-dependency.sh
```

