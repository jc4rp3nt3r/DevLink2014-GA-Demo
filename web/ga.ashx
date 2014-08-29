<%@ WebHandler Language="C#" Class="googeAnalyticsHandler" %>

using System;
using System.IO;
using System.Text;
using System.Web;
using Google.GData.Analytics;
using Google.GData.Client;

public class googeAnalyticsHandler : IHttpHandler
{
    // Set these values for your account
    protected const String  ApplicationName = "CHANGE-ME",
                            Username = "CHANGE-ME",
                            Password = "CHANGE-ME",
                            ApiKey = "CHANGE-ME",
                            AccountId = "CHANGE-ME",
                            ViewId = "CHANGE-ME";

    // do not modify these
    protected const String  AnalyticsBaseUrl = "https://www.googleapis.com/analytics/v3/data/ga",
                            ManagerUrl = "https://www.googleapis.com/analytics/v3/management/accounts/", 
                            SiteId = "ga:" + ViewId,
                            WebPropertyId = "UA-" + AccountId + "-1";
    
    public void ProcessRequest(HttpContext ctx)
    {
        // if this page is called without any parameters, print out instructions
        if (ctx.Request.QueryString.Count == 0)
            ReturnInstructions(ctx);
        
        var sOutput = "{}";
        
        // parse out all QueryString data we could pass in
        var sMetrics = ctx.Request.QueryString["metrics"];
        var sDimensions = ctx.Request.QueryString["dimensions"];
        var sSort = ctx.Request.QueryString["sort"];
        var sFilter = ctx.Request.QueryString["filter"];
        var bGoalData = ctx.Request.QueryString["goals"] == "true";
        
        // read dates or default to last 30 days if they do not parse
        DateTime dtTo, dtFrom;
        if(!DateTime.TryParse(ctx.Request.QueryString["to"], out dtTo))
            dtTo = DateTime.Today.AddDays(-1);
        if (!DateTime.TryParse(ctx.Request.QueryString["from"], out dtFrom))
            dtFrom = dtTo.AddDays(-30);
        
        // b/c Google LOVES to throw errors
        try
        {
            // set up the analytics service
            AnalyticsService analytics = new AnalyticsService(ApplicationName);
            analytics.setUserCredentials(Username, Password);
            
            // create a Google DataQuery Object for use below
            DataQuery dq;
                
            if (bGoalData)
            {
                String sUrl = ManagerUrl + AccountId + "/webproperties/" + WebPropertyId + "/profiles/" + ViewId + "/goals";

                dq = new DataQuery()
                {
                    ExtraParameters = "key=" + ApiKey + "&quotaUser=" + GetUserId(),
                    FeedFormat = AlternativeFormat.Unknown,
                    BaseAddress = sUrl
                };
            }
            else
            {
                // add all the passed parameters 
                dq = new DataQuery(SiteId, dtFrom, dtTo)
                {
                    Metrics = sMetrics,
                    Dimensions = sDimensions,
                    Sort = sSort,
                    Filters = sFilter,
                    NumberToRetrieve = 1000,                                    // ToDo: if more than 1000 results, need to implement pagination
                    ExtraParameters = "key=" + ApiKey + "&alt=json&quotaUser=" + GetUserId(),
                    FeedFormat = AlternativeFormat.Unknown,
                    BaseAddress = AnalyticsBaseUrl
                };
            }

            // the Google Query method returns a Stream, read all data into our output var
            StreamReader sr = new StreamReader(analytics.Query(dq.Uri, dq.ModifiedSince));
            sOutput = sr.ReadToEnd();
        }
        catch (Exception ex)
        {
            // pass the error from google to the response
            sOutput = "Query Failure:<br/>" + ex;
        }

        // Prevent Cache and write output 
        ctx.Response.Cache.SetCacheability(HttpCacheability.NoCache);
        ctx.Response.Cache.SetExpires(DateTime.MinValue);
        ctx.Response.ContentType = "application/json";
        ctx.Response.ContentEncoding = Encoding.UTF8;
        ctx.Response.Write(sOutput);
    }
    
    public bool IsReusable {
        get {
            return false;
        }
    }

    /// <summary>
    /// Creates or retrieves an anonymous UserId Guid to be sent to Google Analytics to rate limit per user
    /// </summary>
    /// <returns>A GUID user id for this user</returns>
    private static String GetUserId()
    {
        String sUserIdCookieName = "GA-UID";

        // get a handle to the context and the current cookie
        HttpContext ctx = HttpContext.Current;
        HttpCookie hc = ctx.Request.Cookies.Get(sUserIdCookieName);

        // if we don't have a cookie, create a GUID ID and save it
        if (hc == null)
        {
            hc = new HttpCookie(sUserIdCookieName);
            hc.Path = "/";
            hc.Value = Guid.NewGuid().ToString();
        }

        // extend the expiration to match GoogleAnalytics 2 year expire date
        hc.Expires = DateTime.Now.AddYears(2);
        ctx.Response.Cookies.Add(hc);

        return hc.Value;
    }
    
    private void ReturnInstructions(HttpContext ctx)
    {
            ctx.Response.Write("<html><body>");
            ctx.Response.Write("<span style='font-family:Consolas;font-size:12px'>");
            ctx.Response.Write("Google Analytics Reference: <a href='https://developers.google.com/analytics/devguides/reporting/core/dimsmets' target='_blank'>https://developers.google.com/analytics/devguides/reporting/core/dimsmets</a></br>");
            ctx.Response.Write("Viewing JSON in Firefox: <a href='https://addons.mozilla.org/en-us/firefox/addon/jsonview/' target='_blank'>https://addons.mozilla.org/en-us/firefox/addon/jsonview/</a></br>");
            ctx.Response.Write("</br>");
            ctx.Response.Write("<b>Available Parameters:</b></br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("Parameter Name | DataType  | Separator  | Required | Default Value   | What is it?                                                     | Example Value(s)                                      </br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------</br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("Metrics        | String    |      ,     |    Yes   | User Value Only | Data Values Returned                                            | ga:visits                                             </br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("Dimensions     | String    |      ,     |    No    | Null            |  Point of Reference for Data                                    | ga:date                                               </br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("Sort           | String    |      ,     |    No    | Null            |  Dimension and Direction To Sort By                             | ga:date (Asc), -ga:date(Desc)                         </br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("Filter         | String    |  See Below |    No    | Null            |  Specific Values of a Given Dimension to Include/Exclude        | ga:country==United States,ga:country!=United States   </br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("From           | DateTime  |     N/A    |    No    | 30 Days Ago     |  Begining Date of Range for which Data will be returned against | dd/mm/yyyy e.g. 11/12/2012                            </br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("To             | DateTime  |     N/A    |    No    | Today           |  Ending Date of Range for which Data will be returned against   | dd/mm/yyyy e.g. 11/30/2012                            </br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("GoalData       | Boolean   |     N/A    |    Yes   | User Value Only |  Handler to returned Goal Information                           | true (Goal Info)                                      </br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("</br>");
            ctx.Response.Write("<b>Filtering Expressions - Metrics:</b></br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------</br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("Operator  |  Description               | URL Encoded Form                                                                                                                                      </br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------</br>".Replace(" ","&nbsp;"));
            ctx.Response.Write("   ==     | Equals                     |      %3D%3D</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   !=     | Does not equal             |      !%3D</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   >      | Greater than               |      %3E</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   <      | Less than                  |      %3C</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   >=     | Greater than or equal to   |      %3E%3D</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   <=     | Less than or equal to      |      %3C%3D</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("</br>");
            ctx.Response.Write("<b>Filtering Expressions - Dimensions:</b></br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("Operator  |  Description                                  | URL Encoded Form                                                                                                                   </br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   ==     | Exact Match                                   |      %3D%3D</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   !=     | Does not match                                |      !%3D</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   =@     | Contains substring                            |      %3D@</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   !@     | Does not contain substring                    |      !@</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   =~     | Contains a match for the regular expression   |      %3D~</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("   !~     | Does not match regular expression             |      !~</br>".Replace(" ", "&nbsp;"));
            ctx.Response.Write("</br>");
            ctx.Response.Write("</span>");
            ctx.Response.Write("</body></html>");
            ctx.Response.End();
    }
}