# Alcohol Screening and Brief Intervention (ASBI) Clinical Decision Support (CDS) Screening App
The *ASBI Screening App* is a [SMART on FHIR<sup>&reg;</sup>](https://docs.smarthealthit.org/) application that provides multiple alcohol screening instruments for assessing patient alcohol consumption behaviors. The app is meant to be used with the [SMART<sup>&reg;</sup> app launch framework](http://hl7.org/fhir/smart-app-launch/index.html) and is designed to customize the alcohol screening based upon patient-specific characteristics and data provided by an electronic health record (EHR). If write-back capability is supported by an organization integrating the *ASBI Screening App* into their EHR, then the patient responses to the alcohol screening are also written back to the patient record.

The *ASBI Screening App* currently supports the following alcohol screening instruments:
1. World Health Organization's Alcohol Use Disorders Identification Test (AUDIT)
2. United States AUDIT (USAUDIT)
3. National Institute on Substance Abuse (NIDA) Quick Screen

Each of the above have been represented as interoperable CDS and have been published on the [CDS Connect Repository](https://cds.ahrq.gov/cdsconnect/artifact_discovery).

An online demo of this app is avaiable; please see the [Demo](#demo) section.

## Cautions and Limitations
This software application has not been tested in a clinical environment with real patient data. Its purpose is to faciliate testing of the three alcohol screening CDS to be published on CDS Connect. Additional development work will be needed to integrate the *ASBI Screening App* into a real EHR.

## Utilized Standards
A number of standards have been used to help define the *ASBI Screening App*.

### SMART on FHIR<sup>&reg;</sup>
The [Substitutable Medical Apps, Reusable Technology (SMART)](https://smarthealthit.org/) on Fast Healthcare Interoperability Resources (FHIR<sup>&reg;</sup>) is a free and open standards-based application programming interface (API) for providing software applications with access to electronic health records (EHRs). The *ASBI Screening App* uses the SMART on FHIR<sup>&reg;</sup> standard to access patient data in order to customize the alcohol screening experience.

### FHIR<sup>&reg;</sup> Questionnaire
[Questionnaire](https://www.hl7.org/fhir/questionnaire.html) is one of the many [interoperable resources](http://hl7.org/fhir/resourcelist.html) defined by the Health Level 7 (HL7<sup>&reg;</sup>) [FHIR<sup>&reg;</sup> standard](http://hl7.org/fhir/). The Questionnaire resource allows a set of questions and allowable responses to be represented in an open and standard way. Each Questionnaire is defined by a set of both required and optional data elements, which are [by design](https://www.hl7.org/fhir/questionnaire.html#sdc) general in nature in order to support the capabilities most likely to be found in most healthcare systems. The *ASBI Screening App* uses a separate Questionnaire to represent each of the available alcohol screening instruments. A [QuestionnaireResponse](https://www.hl7.org/fhir/questionnaireresponse.html) resource is generated from the responses provided by the patient.

### Structured Data Capture (SDC)
The base FHIR<sup>&reg;</sup> specification is meant to be an [80% solution](https://www.hl7.org/fhir/overview-arch.html#principles) for healthcare interoperability. Mechanisms such as extensions, profiles, and implementation guides [provide a means](https://www.hl7.org/fhir/extensibility.html) in which use cases outside this 80% can be addressed. The [Structured Data Capture (SDC) implementation guide](http://build.fhir.org/ig/HL7/sdc/) defines how more complex Questionnaire functionality and behavior can be expressed. Examples of additional complexity used within the *ASBI Screening App* include advanced rendering of the Questionnaires and the ability to provide dynamic updates via logical expressions (see "Clinical Quality Language (CQL)" below).

### Clinical Quality Language (CQL)
[CQL](https://cql.hl7.org/) is a domain-specific programming language focused on clinical quality applications, including CDS as well as electronic clinical quality measures (eCQMs). Logical expressions written in CQL are human-readable but can also be compiled to a machine-friendly format to facilitate implementation. The *ASBI Screening App*  executes CQL logic embedded in each Questionnaire to provide patient customized behavior.

## Underlying Technologies

### Vue.js
[Vue](https://vuejs.org/) is a JavaScript front-end framework for building user interfaces. The *ASBI Screening App* was built using the [`vue create` command](https://cli.vuejs.org/guide/creating-a-project.html#vue-create) from the Vue command line interface (CLI).

### SurveyJS
[SurveyJS](https://github.com/surveyjs/survey-library) is a JavaScript library for rendering surveys and forms in a web browser and capturing user responses. The *ASBI Screening App* uses SurveyJS to mechanize the alcohol screening instruments.

### Questionnaire to Survey
While SurveyJS provides many capabilities which are similiar to those described by FHIR<sup>&reg;</sup> and SDC, it is not currently able to ingest FHIR<sup>&reg;</sup> Questionnaires. The *Questionnaire to Survey* library allows surveys defined as FHIR<sup>&reg;</sup> Questionnaires to be used with SurveyJS.

### CQL Execution Engine
All CQL calculations are executed using the [CQL Execution Engine](https://github.com/cqframework/cql-execution), an open source library that implements the CQL standard.

### Web Workers
All CQL calculations are executed within the context of a [Web Worker](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers), thereby offloading them to a separate thread. This greatly improves the responsiveness of the application.

## Usage
While the *ASBI Screening App* is meant to interface with an actual EHR, a number of options are available for local testing with synthetic data.

### Setup
This project manages dependencies using the [Yarn package manager](https://yarnpkg.com/). The dependencies for the *ASBI Screening App* can be installed locally by typing `yarn` at the command line. A local version of the app can be launched by typing `yarn serve` at the command line. A copy suitable for distribution can be built using the `yarn build` command.

### Download Value Sets from VSAC
The value set content used by the CQL is cached in a file named valueset-db.json, which has been checked into this project in an empty state. In order for the CDS to operate as intended, implementers must populate valueset-db.json with the value sets which have been published on the [Value Set Authority Center (VSAC)](https://vsac.nlm.nih.gov/). In order to access VSAC, you must sign up for a [UMLS Terminology Services account](https://uts.nlm.nih.gov//license.html).

Once a UMLS Terminology Services account has been obtained, the valueset-db.json file can be updated by running the following:

1. Run `node src/util/updateValueSetDB.js UMLS_API_KEY` _(replacing UMLS\_API\_KEY with your actual UMLS API key)_

To get you UMLS API Key:

1. Sign into your UMLS account at [https://uts.nlm.nih.gov/uts.html](https://uts.nlm.nih.gov/uts.html)
2. Click 'My Profile' in the orange banner at the top of the screen
3. Your API key should be listed below your username in the table
4. If no API key is listed:
   1. Click ‘Edit Profile’
   2. Select the ‘Generate new API Key’ checkbox
   3. Click ‘Save Profile’
   4. Your new API key should now be listed.

### Configuration
Parameters for the app are stored in [environmental variables](http://man7.org/linux/man-pages/man7/environ.7.html) that are stored in an `.env` file. The [dotenv package](https://www.npmjs.com/package/dotenv) is used to store the default variable values, which can be overwritten by defining a more specific env (e.g., `.env.local`) file or by setting the variables in the deployment system. For more information, see the [Vue documentation](https://cli.vuejs.org/guide/mode-and-env.html#environment-variables).

#### Parameters

| Parameter | Description | Allowed Values |
| --- | --- | --- |
| `VUE_APP_DISPLAY_SCREENING_SCORES` | Override option to display scores during the alcohol screening. If set to `true` the scores will still only be displayed if the appropriate questions are answered. If set to `false` no scores are ever displayed to the screen. | `['true', 'false']` |
| `VUE_APP_WRITE_BACK_MODE` | Sets the mode for writing out a `QuestionnaireResponse` resource after the completion of screening. If set to `smart` then the resource is sent back via the SMART on FHIR<sup>&reg;</sup> interface to be created in the EHR. If set to `none` then no write back is made | `['smart', 'none']` |
| `VUE_APP_QUESTIONNAIRE_AUTHOR` | Used for indicating who is actually filling out and submitting the `QuestionnaireResponse` resource. This is used to determine how to fill out the `QuestionnaireResponse.author` element. | `['practitioner', 'patient']` |
| `VUE_APP_FHIR_OBSERVATION_CATEGORY_QUERIES` | Some FHIR<sup>&reg;</sup> APIs require `Observation` resource queries to specify an [observation category](https://www.hl7.org/fhir/codesystem-observation-category.html). Setting this parameter to `true` causes the query of a patient's `Observation` resources to be made specified using categories. | `['true', 'false']` |
| `VUE_APP_ALCOHOL_SCREENING_INSTRUMENT` | For selecting which alcohol screening instrument is presented to the user. | `['usaudit', 'whoaudit', 'nidaqs2usaudit', 'phq9']` |

### Using with ASBI Testing Server
This option requires installing the [ASBI Testing Server](https://github.com/asbi-cds-tools/asbi-testing-server):
1. `yarn start` in the root of the ASBI Testing Server (after installing its dependencies)
2. `yarn serve` from this project
3. Open a web browser and navigate to [http://localhost:8080/selector.html](http://localhost:8080/selector.html)
4. Select a synthetic patient from the list

This will start the SMART on FHIR<sup>&reg;</sup> launch sequence, which if everything is working should result in the ASBI Screening App being displayed. A series of FHIR<sup>&reg;</sup> queries will be made from from this app to the ASBI Testing Server, which will respond with the appropriate resources.

### Using with Public SMART Sandbox
A public [SMART App Launcher](https://launch.smarthealthit.org/index.html) is available for sandbox tesing of SMART on FHIR<sup>&reg;</sup> apps with synthetic data. In order to use this option, the *ASBI Screening App* must be served over a Hypertext Transfer Protocol Secure (HTTPS) connection.

#### EHR Launch
Navigate to the public SMART<sup>&reg;</sup> App Launcher and choose the "Provider EHR Launch" Launch Type. Leave all other options unselected. Paste the URL to where `public/launch_public_ehr.html` is being served from into the "App Launch URL" box at the bottom of the SMART<sup>&reg;</sup> App Launcher page. Select "Launch App!" which will bring up a patient selector widget before the *ASBI Screening App* is launched.

#### Standalone Launch
Select the "Provider Standalone Launch" option in the public SMART<sup>&reg;</sup> App Launcher. Copy the "FHIR<sup>&reg;</sup> Server URL" shown at the bottom of the screen and paste it into the `iss` field in `public/launch_public_standalone.html`. Navigate to where `public/launch_public_standalone.html` is being served from and you should be redirected to the patient selector widget.

##### Demo
An online [demo](https://launch.smarthealthit.org/launcher?launch_uri=https%3A%2F%2Fasbi-cds-tools.github.io%2Fasbi-screening-app%2Flaunch.html&fhir_ver=4) of the *ASBI Screening App* is available, configured to use the WHO AUDIT. The [demo](https://launch.smarthealthit.org/launcher?launch_uri=https%3A%2F%2Fasbi-cds-tools.github.io%2Fasbi-screening-app%2Flaunch.html&fhir_ver=4) utilizes the public SMART sandbox with standalone launch and the use of any recent version of the Chrome browser is recommended. Other browsers have not yet been extensively tested with the demo app.

## License
(C) 2021 The MITRE Corporation. All Rights Reserved. Approved for Public Release: 20-0458. Distribution Unlimited.

Unless otherwise noted, this work is available under an Apache 2.0 license. It was produced by the MITRE Corporation for the National Center on Birth Defects and Developmental Disabilities, Centers for Disease Control and Prevention in accordance with the Statement of Work, contract number 75FCMC18D0047, task order number 75D30119F05691.

Any LOINC (http://loinc.org) content is copyright &copy; 1995-2020, Regenstrief Institute, Inc. and the Logical Observation Identifiers Names and Codes (LOINC) Committee and is available at no cost under the license at http://loinc.org/license. LOINC<sup>&reg;</sup> is a registered United States trademark of Regenstrief Institute, Inc.

References to and reproductions of the AUDIT alcohol screening instrument are made by permission from the World Health Organization (WHO). The WHO does not endorse this project, does not provide any warranty, and does not assume any liability for its use. For further information, please see:

Alcohol Use Disorders Identification Test - Guidelines for Use in Primary Care, Second Edition. Geneva, World Health Organization, 2001.

AUDIT (C) World Health Organization 2001

https://www.who.int/substance_abuse/activities/sbi/en/
