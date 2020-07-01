
import questionnaireUsAudit from '../fhir/Questionnaire-USAUDIT.json';
import questionnaireWhoAudit from '../fhir/Questionnaire-WHOAUDIT.json';
import questionnaireNidaQs from '../fhir/Questionnaire-NIDAQS2USAUDIT.json';
import elmJsonUsAudit from '../cql/UsAuditLogicLibrary.json';
import elmJsonWhoAudit from '../cql/WhoAuditLogicLibrary.json';
import elmJsonNidaQs from '../cql/NidaQsToUsAuditLogicLibrary.json';
import valueSetJsonUsAudit from '../cql/valueset-db.json';


export function getScreeningInstrument() {
  let screeningInstrument = process.env.VUE_APP_ALCOHOL_SCREENING_INSTRUMENT.toLowerCase();

  if (screeningInstrument == 'usaudit') {
    return [questionnaireUsAudit, elmJsonUsAudit, valueSetJsonUsAudit];
  } else if (screeningInstrument == 'whoaudit') {
    return [questionnaireWhoAudit, elmJsonWhoAudit, valueSetJsonUsAudit];
  } else if (screeningInstrument == 'nidaqs2usaudit') {
    return [questionnaireNidaQs, elmJsonNidaQs, valueSetJsonUsAudit];
  } else {
    throw new Error('Unsupported alcohol screening instrument has been specified');
  }
}