#!/bin/sh
substituteInPlace font-patcher \
    --replace-fail 'c_handler.setLevel(logging.INFO)' 'c_handler.setLevel(logging.WARNING)' \
    --replace-fail 'print("{} {}".format(projectName, allversions))' 'logger.info("%s %s", projectName, allversions)' \
    --replace-fail 'print("Done with Patch Sets, generating font...")' 'logger.info("Done with Patch Sets, generating font...")'
