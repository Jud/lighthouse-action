const fs = require('fs');
const puppeteer = require('puppeteer');
const lighthouse = require('lighthouse');
const ReportGenerator = require('lighthouse/report/generator/report-generator');

// This port will be used by Lighthouse later. The specific port is arbitrary.
const PORT = 8041;

/**
 * @param {import('puppeteer').Browser} browser
 * @param {string} origin
 */
async function login(browser, origin, password) {
  const page = await browser.newPage();
  const response = await page.goto(origin);

  if (response.status() === 200) {
    return await page.close()
  }

  await page.waitForSelector('input[type="password"]', {visible: true});

  // Fill in and submit login form.
  const passwordInput = await page.$('input[type="password"]');
  await passwordInput.type(password);
  await Promise.all([
    page.$eval('form', form => form.submit()),
    page.waitForNavigation(),
  ]);

  await page.close();
}

async function generate_report_for(url, browser, password) {
  // Setup the browser session to be logged into our site.
  await login(browser, url, password);

  // Direct Lighthouse to use the same port.
  return await lighthouse(url, {onlyCategories: ['performance'], port: PORT, disableStorageReset: true})
}

function write_report(json, html, path) {
  fs.writeFileSync(`${path}.report.html`, html);
  fs.writeFileSync(`${path}.report.json`, json.report);
}

async function main() {
  // Direct Puppeteer to open Chrome with a specific debugging port.
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: [`--remote-debugging-port=${PORT}`, '--disable-gpu', '--no-sandbox', '--no-zygote'],
    // Optional, if you want to see the tests in action.
    headless: true,
  });

  const branch_report = await generate_report_for(process.env.URL, browser, process.env.NETLIFY_AUTH);
  write_report(branch_report, ReportGenerator.generateReport(branch_report.lhr, 'html'), process.env.REPORT_PATH)

  if (process.env.BASE_URL) {
    const base_report = await generate_report_for(process.env.BASE_URL, browser, process.env.NETLIFY_BASE_AUTH || process.env.NETLIFY_AUTH);
    write_report(base_report, ReportGenerator.generateReport(base_report.lhr, 'html'), process.env.BASE_REPORT_PATH)
  }

  // Direct Puppeteer to close the browser as we're done with it.
  await browser.close();
}

if (require.main === module) {
  main();
} else {
  module.exports = {
    login,
  };
}
