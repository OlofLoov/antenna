## ADDED Requirements

### Requirement: The site is served over HTTPS on Antenna's domain
The system SHALL serve the website at Antenna's own domain over HTTPS with a certificate for that name, SHALL answer a plain HTTP request with a permanent redirect to the same address over HTTPS, and SHALL tell browsers to use HTTPS for that domain from then on.

#### Scenario: Opening the site
- **WHEN** someone opens the domain's home address in a browser
- **THEN** the page loads over HTTPS with a valid certificate for the domain, and the browser shows no warning

#### Scenario: Typing http
- **WHEN** someone opens the Terms of Use with `http://`
- **THEN** they land on the same page over HTTPS

#### Scenario: A folder address without a trailing slash
- **WHEN** someone opens `/privacy` or `/privacy/`
- **THEN** the Privacy Policy shows at either address

#### Scenario: An address that does not exist
- **WHEN** someone opens an address the site has no page for
- **THEN** a short "Page not found" page shows with a link to the home page, with a not-found status

### Requirement: The site's files cannot be read around it
The system SHALL keep the site's stored files private, readable only through the site's own address.

#### Scenario: Asking the storage directly
- **WHEN** someone requests a page from the storage behind the site instead of the domain
- **THEN** the request is refused

### Requirement: The API answers on its own address
The system SHALL serve the API at `api.` on Antenna's domain over HTTPS only, SHALL answer an address it has no route for with a not-found status and no detail, and SHALL refuse requests that reach the API without passing through that address.

#### Scenario: A route that does not exist
- **WHEN** someone requests a path the API has no route for
- **THEN** it answers not found, with no stack trace, version or server name in the answer

#### Scenario: Going around the address
- **WHEN** someone calls the API's internal AWS address directly
- **THEN** the request is refused

#### Scenario: Too many requests from one address
- **WHEN** one network address sends requests faster than the API's rate limit
- **THEN** further requests are refused with a too-many-requests status until the rate drops

### Requirement: Nothing keeps a record of requests
The system SHALL keep no log of the addresses, query strings, bodies or network addresses of requests to the site or the API, and SHALL keep only counts, errors and the deploys themselves.

#### Scenario: Looking for who opened a page
- **WHEN** the owner looks in the AWS account for which network addresses opened the Privacy Policy
- **THEN** there is no log that holds it, only a count of requests

#### Scenario: A service fails
- **WHEN** an API route fails
- **THEN** its log line names the route and the error, and not the query, the body or the caller's address
- **AND** the line is deleted after 14 days

### Requirement: Deploys come only from main
The system SHALL change the site and the infrastructure only from a workflow run on main, authenticated to AWS with a short-lived token for that run, with no AWS key stored in the repository or its settings.

#### Scenario: A pull request changes the infrastructure
- **WHEN** a pull request edits the infrastructure
- **THEN** the pull request shows what would change in AWS, and nothing in AWS changes

#### Scenario: The pull request merges
- **WHEN** it merges to main
- **THEN** the infrastructure change is applied after the owner approves the run, and the site is uploaded again

#### Scenario: A branch tries to deploy
- **WHEN** a workflow on any branch other than main asks AWS for the deploy role
- **THEN** AWS refuses it

#### Scenario: A site edit merges
- **WHEN** a pull request that edits only a page under the website merges
- **THEN** the new page is live within 15 minutes with no approval

### Requirement: The owner hears about cost before it grows
The system SHALL alert the owner when the month's AWS cost passes half of the monthly budget, and again when it passes or is forecast to pass the whole budget.

#### Scenario: A traffic spike
- **WHEN** the month's forecast passes the budget
- **THEN** the owner gets an alert that day

### Requirement: The domain receives no email
The system SHALL publish no mail records for Antenna's domain, so mail sent to any address at it is not accepted.

#### Scenario: Someone writes to the domain
- **WHEN** someone sends an email to an address at Antenna's domain
- **THEN** their mail server reports that it could not be delivered
