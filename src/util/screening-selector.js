
import valueSetJsonUsAudit from '../cql/valueset-db.json';

//dynamically load questionnaire and cql JSON
export async function getScreeningInstrument() {
  let screeningInstrument = process.env.VUE_APP_ALCOHOL_SCREENING_INSTRUMENT ? 
  process.env.VUE_APP_ALCOHOL_SCREENING_INSTRUMENT.toLowerCase() : "";
  if (screeningInstrument == 'usaudit') {
    let questionnaireUsAudit = await import("../fhir/Questionnaire-USAUDIT.json").then(module=>module.default);
    let elmJsonUsAudit = await import("../cql/UsAuditLogicLibrary.json").then(module=>module.default);
    return [questionnaireUsAudit, elmJsonUsAudit, valueSetJsonUsAudit];
  } else if (screeningInstrument == 'whoaudit') {
    let questionnaireWhoAudit = await import("../fhir/Questionnaire-WHOAUDIT.json").then(module=>module.default);
    let elmJsonWhoAudit = await import("../cql/WhoAuditLogicLibrary.json").then(module=>module.default);
    return [questionnaireWhoAudit, elmJsonWhoAudit, valueSetJsonUsAudit];
  } else if (screeningInstrument == 'nidaqs2usaudit') {
    let questionnaireNidaQs = await import("../fhir/Questionnaire-NIDAQS2USAUDIT.json").then(module=>module.default);
    let elmJsonNidaQs = await import("../cql/NidaQsToUsAuditLogicLibrary.json").then(module=>module.default);
    return [questionnaireNidaQs, elmJsonNidaQs, valueSetJsonUsAudit];
  } else {
    throw new Error('Unsupported alcohol screening instrument has been specified');
  }
}
