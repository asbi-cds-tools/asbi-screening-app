<template>
  <v-app id="launch">
    <div>Loading...</div>
  </v-app>
</template>

<script>
import FHIR from 'fhirclient';

const urlParams = new URLSearchParams(window.location.search);
let patientId = urlParams.get('patient');
if (patientId == null) patientId = '123';
FHIR.oauth2.authorize({
    clientId: "dummy-client-id",
    scope: "patient/Patient.read patient/Condition.read patient/Observation.read patient/Procedure.read patient/QuestionnaireResponse.read online_access openid fhirUser patient/QuestionnaireResponse.write",
    iss: "http://localhost:3000/4_0_0",
    launch: patientId
});

export default {
  name: 'Launch'
}
</script>

<style>
</style>
