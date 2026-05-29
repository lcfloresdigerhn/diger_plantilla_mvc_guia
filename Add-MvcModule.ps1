<#
.SYNOPSIS
    Agrega un MODULO (proyecto MVC independiente) a una solucion creada con
    New-MvcProject.ps1, enlazandolo al proyecto PRINCIPAL al estilo SISS
    (donde MDX/DSP/PPX son proyectos aparte que referencian la plataforma base).

.DESCRIPTION
    - Crea un nuevo proyecto MVC 5 (.NET 4.8) dentro de la misma carpeta de la
      solucion, como hermano del proyecto principal.
    - Lo agrega al archivo .sln existente (entrada de proyecto + configuraciones).
    - Agrega una ProjectReference al proyecto principal: el HomeController del
      modulo HEREDA del BaseController de la app principal (reutiliza la logica
      de ValidaSesion/ModoDesarrollo). No duplica el BaseController.
    - El modulo es ejecutable por si mismo (su propio Global.asax, Web.config y
      puerto de IIS Express). Para correrlo: clic derecho en el proyecto del
      modulo -> "Set as Startup Project" -> F5.

    Comparte la carpeta 'packages' de la solucion (igual que el principal).

.PARAMETER Name
    Nombre del modulo/proyecto. Ej: "Inventario".

.PARAMETER SolutionPath
    Ruta al .sln o a la carpeta que lo contiene. Por defecto la carpeta actual.

.PARAMETER MainProject
    Nombre del proyecto principal a referenciar. Si se omite, se usa el primero
    de la solucion.

.PARAMETER SqlServer
    Instancia SQL Server. Por defecto se hereda del Web.config del principal.

.PARAMETER Database
    Base de datos. Por defecto se hereda del Web.config del principal.

.PARAMETER Port
    Puerto de IIS Express del modulo. Por defecto aleatorio (44300-44399).

.EXAMPLE
    .\Add-MvcModule.ps1 -Name Inventario -SolutionPath .\Hola

.EXAMPLE
    .\Add-MvcModule.ps1 -Name Reportes -SolutionPath .\Hola\Hola.sln -MainProject Hola -Port 44390
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')]
    [string]$Name,

    [string]$SolutionPath = (Get-Location).Path,

    [string]$MainProject,

    [string]$SqlServer,

    [string]$Database,

    [int]$Port = (Get-Random -Minimum 44300 -Maximum 44399)
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. Localizar el .sln y la carpeta de la solucion
# ---------------------------------------------------------------------------
if ($SolutionPath -match '\.sln$') {
    if (-not (Test-Path $SolutionPath)) { throw "No existe el archivo: $SolutionPath" }
    $slnFile = (Resolve-Path $SolutionPath).Path
} else {
    if (-not (Test-Path $SolutionPath)) { throw "No existe la carpeta: $SolutionPath" }
    $dir  = (Resolve-Path $SolutionPath).Path
    $slns = @(Get-ChildItem -Path $dir -Filter *.sln -File)
    if ($slns.Count -eq 0) { throw "No se encontro ningun .sln en '$dir'. Usa -SolutionPath con la ruta al .sln." }
    if ($slns.Count -gt 1) { throw "Hay varios .sln en '$dir'. Usa -SolutionPath con la ruta exacta al .sln." }
    $slnFile = $slns[0].FullName
}
$slnDir = Split-Path $slnFile -Parent

# ---------------------------------------------------------------------------
# 2. Parsear proyectos del .sln y elegir el PRINCIPAL
# ---------------------------------------------------------------------------
$slnRaw = Get-Content -LiteralPath $slnFile -Raw
$projMatches = [regex]::Matches(
    $slnRaw,
    'Project\("\{[0-9A-Fa-f\-]+\}"\)\s*=\s*"([^"]+)",\s*"([^"]+\.csproj)",\s*"\{([0-9A-Fa-f\-]+)\}"')

if ($projMatches.Count -eq 0) { throw "El .sln no contiene proyectos .csproj reconocibles." }

if ($MainProject) {
    $main = $projMatches | Where-Object { $_.Groups[1].Value -eq $MainProject } | Select-Object -First 1
    if (-not $main) { throw "No se encontro el proyecto principal '$MainProject' en el .sln." }
} else {
    $main = $projMatches[0]
}
$mainName = $main.Groups[1].Value
$mainRel  = $main.Groups[2].Value                       # ej: Hola\Hola.csproj
$mainGuid = $main.Groups[3].Value.ToUpper()

# Validar que no choque con el nombre del modulo
if ($projMatches | Where-Object { $_.Groups[1].Value -eq $Name }) {
    throw "Ya existe un proyecto llamado '$Name' en la solucion."
}

$mainCsproj = Join-Path $slnDir $mainRel
if (-not (Test-Path $mainCsproj)) { throw "No se encontro el .csproj principal en: $mainCsproj" }

# RootNamespace del principal (para 'using' del BaseController)
$mainXml = Get-Content -LiteralPath $mainCsproj -Raw
$mainNs  = ([regex]::Match($mainXml, '<RootNamespace>([^<]+)</RootNamespace>')).Groups[1].Value
if (-not $mainNs) { $mainNs = $mainName }

# ---------------------------------------------------------------------------
# 3. Heredar SqlServer / Database del Web.config del principal si no se pasaron
# ---------------------------------------------------------------------------
$mainWebConfig = Join-Path (Split-Path $mainCsproj -Parent) 'Web.config'
if ((-not $SqlServer -or -not $Database) -and (Test-Path $mainWebConfig)) {
    $wc = Get-Content -LiteralPath $mainWebConfig -Raw
    $m  = [regex]::Match($wc, 'data source=([^;"]+);initial catalog=([^;"]+);')
    if ($m.Success) {
        if (-not $SqlServer) { $SqlServer = $m.Groups[1].Value }
        if (-not $Database)  { $Database  = $m.Groups[2].Value }
    }
}
if (-not $SqlServer) { $SqlServer = 'localhost\SQLEXPRESS' }
if (-not $Database)  { $Database  = $Name }

# ---------------------------------------------------------------------------
# 4. Calcular rutas / GUID del modulo
# ---------------------------------------------------------------------------
$modGuid = ([guid]::NewGuid()).ToString().ToUpper()
$modDir  = Join-Path $slnDir $Name
if (Test-Path $modDir) { throw "Ya existe la carpeta '$modDir'. Elige otro nombre o borrala." }

# Ruta relativa desde la carpeta del modulo hacia el .csproj principal
$mainRefRel = '..\' + $mainRel                          # ej: ..\Hola\Hola.csproj

$root = $slnDir   # las plantillas escriben en <slnDir>\<Name>\...

# ---------------------------------------------------------------------------
# Helper: escribe archivo con reemplazo de tokens (UTF-8 sin BOM)
# ---------------------------------------------------------------------------
function Write-TemplateFile {
    param([string]$RelativePath, [string]$Content)

    $RelativePath = $RelativePath.Replace('__NAME__', $Name)
    $full = Join-Path $root $RelativePath
    $dir  = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $Content = $Content.Replace('__NAME__',     $Name)
    $Content = $Content.Replace('__SERVER__',   $SqlServer)
    $Content = $Content.Replace('__DB__',       $Database)
    $Content = $Content.Replace('__GUID__',     $modGuid)
    $Content = $Content.Replace('__PORT__',     "$Port")
    $Content = $Content.Replace('__MAIN__',     $mainName)
    $Content = $Content.Replace('__MAINNS__',   $mainNs)
    $Content = $Content.Replace('__MAINGUID__', $mainGuid)
    $Content = $Content.Replace('__MAINREF__',  $mainRefRel)

    # La declaracion <?xml ?> debe ser lo primero del archivo (sin lineas en blanco antes).
    $Content = $Content.TrimStart([char]13, [char]10)

    [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "  + $RelativePath" -ForegroundColor DarkGray
}

Write-Host "Agregando modulo '$Name' a la solucion '$([System.IO.Path]::GetFileName($slnFile))'" -ForegroundColor Cyan
Write-Host "  principal = $mainName  ($mainNs)" -ForegroundColor DarkGray

# ===========================================================================
#  packages.config (mismos paquetes que el principal)
# ===========================================================================
Write-TemplateFile "__NAME__\packages.config" @'
<?xml version="1.0" encoding="utf-8"?>
<packages>
  <package id="Antlr" version="3.5.0.2" targetFramework="net48" />
  <package id="EntityFramework" version="6.5.1" targetFramework="net48" />
  <package id="Microsoft.AspNet.Mvc" version="5.2.9" targetFramework="net48" />
  <package id="Microsoft.AspNet.Razor" version="3.2.9" targetFramework="net48" />
  <package id="Microsoft.AspNet.Web.Optimization" version="1.1.3" targetFramework="net48" />
  <package id="Microsoft.AspNet.WebPages" version="3.2.9" targetFramework="net48" />
  <package id="Microsoft.Web.Infrastructure" version="2.0.0" targetFramework="net48" />
  <package id="Newtonsoft.Json" version="13.0.3" targetFramework="net48" />
  <package id="WebGrease" version="1.6.0" targetFramework="net48" />
</packages>
'@

# ===========================================================================
#  .csproj del modulo (igual al principal + ProjectReference, sin BaseController)
# ===========================================================================
Write-TemplateFile "__NAME__\__NAME__.csproj" @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="15.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <ProductVersion>
    </ProductVersion>
    <SchemaVersion>2.0</SchemaVersion>
    <ProjectGuid>{__GUID__}</ProjectGuid>
    <ProjectTypeGuids>{349c5851-65df-11da-9384-00065b846f21};{fae04ec0-301f-11d3-bf4b-00c04f79efbc}</ProjectTypeGuids>
    <OutputType>Library</OutputType>
    <AppDesignerFolder>Properties</AppDesignerFolder>
    <RootNamespace>__NAME__</RootNamespace>
    <AssemblyName>__NAME__</AssemblyName>
    <TargetFrameworkVersion>v4.8</TargetFrameworkVersion>
    <MvcBuildViews>false</MvcBuildViews>
    <UseIISExpress>true</UseIISExpress>
    <Use64BitIISExpress />
    <IISExpressSSLPort>__PORT__</IISExpressSSLPort>
    <IISExpressAnonymousAuthentication />
    <IISExpressWindowsAuthentication />
    <IISExpressUseClassicPipelineMode />
    <UseGlobalApplicationHostFile />
    <NuGetPackageImportStamp>
    </NuGetPackageImportStamp>
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
    <DebugSymbols>true</DebugSymbols>
    <DebugType>full</DebugType>
    <Optimize>false</Optimize>
    <OutputPath>bin\</OutputPath>
    <DefineConstants>DEBUG;TRACE</DefineConstants>
    <ErrorReport>prompt</ErrorReport>
    <WarningLevel>4</WarningLevel>
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
    <DebugType>pdbonly</DebugType>
    <Optimize>true</Optimize>
    <OutputPath>bin\</OutputPath>
    <DefineConstants>TRACE</DefineConstants>
    <ErrorReport>prompt</ErrorReport>
    <WarningLevel>4</WarningLevel>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="Antlr3.Runtime, Version=3.5.0.2, Culture=neutral, PublicKeyToken=eb42632606e9261f, processorArchitecture=MSIL">
      <HintPath>..\packages\Antlr.3.5.0.2\lib\Antlr3.Runtime.dll</HintPath>
    </Reference>
    <Reference Include="EntityFramework, Version=6.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089, processorArchitecture=MSIL">
      <HintPath>..\packages\EntityFramework.6.5.1\lib\net45\EntityFramework.dll</HintPath>
    </Reference>
    <Reference Include="EntityFramework.SqlServer, Version=6.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089, processorArchitecture=MSIL">
      <HintPath>..\packages\EntityFramework.6.5.1\lib\net45\EntityFramework.SqlServer.dll</HintPath>
    </Reference>
    <Reference Include="Microsoft.Web.Infrastructure, Version=2.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.Web.Infrastructure.2.0.0\lib\net40\Microsoft.Web.Infrastructure.dll</HintPath>
    </Reference>
    <Reference Include="Newtonsoft.Json, Version=13.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed, processorArchitecture=MSIL">
      <HintPath>..\packages\Newtonsoft.Json.13.0.3\lib\net45\Newtonsoft.Json.dll</HintPath>
    </Reference>
    <Reference Include="System" />
    <Reference Include="System.ComponentModel.DataAnnotations" />
    <Reference Include="System.Configuration" />
    <Reference Include="System.Core" />
    <Reference Include="System.Data" />
    <Reference Include="System.Data.DataSetExtensions" />
    <Reference Include="System.Web.DynamicData" />
    <Reference Include="System.Web.Entity" />
    <Reference Include="System.Web.ApplicationServices" />
    <Reference Include="System.Web.Extensions" />
    <Reference Include="System.Web.Abstractions" />
    <Reference Include="System.Web.Routing" />
    <Reference Include="System.Xml" />
    <Reference Include="System.Configuration.Install" />
    <Reference Include="System.Xml.Linq" />
    <Reference Include="Microsoft.CSharp" />
    <Reference Include="System.Web" />
    <Reference Include="System.Web.Helpers, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.Helpers.dll</HintPath>
    </Reference>
    <Reference Include="System.Web.Mvc, Version=5.2.9.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.AspNet.Mvc.5.2.9\lib\net45\System.Web.Mvc.dll</HintPath>
    </Reference>
    <Reference Include="System.Web.Optimization, Version=1.1.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.AspNet.Web.Optimization.1.1.3\lib\net40\System.Web.Optimization.dll</HintPath>
    </Reference>
    <Reference Include="System.Web.Razor, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.AspNet.Razor.3.2.9\lib\net45\System.Web.Razor.dll</HintPath>
    </Reference>
    <Reference Include="System.Web.WebPages, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.dll</HintPath>
    </Reference>
    <Reference Include="System.Web.WebPages.Deployment, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.Deployment.dll</HintPath>
    </Reference>
    <Reference Include="System.Web.WebPages.Razor, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.Razor.dll</HintPath>
    </Reference>
    <Reference Include="WebGrease, Version=1.6.5135.21930, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\packages\WebGrease.1.6.0\lib\WebGrease.dll</HintPath>
    </Reference>
  </ItemGroup>
  <ItemGroup>
    <!-- Enlace al proyecto PRINCIPAL: aqui vive el BaseController que reutiliza el modulo -->
    <ProjectReference Include="__MAINREF__">
      <Project>{__MAINGUID__}</Project>
      <Name>__MAIN__</Name>
    </ProjectReference>
  </ItemGroup>
  <ItemGroup>
    <Compile Include="App_Start\BundleConfig.cs" />
    <Compile Include="App_Start\FilterConfig.cs" />
    <Compile Include="App_Start\RouteConfig.cs" />
    <Compile Include="Controllers\HomeController.cs" />
    <Compile Include="Global.asax.cs">
      <DependentUpon>Global.asax</DependentUpon>
    </Compile>
    <Compile Include="Properties\AssemblyInfo.cs" />
  </ItemGroup>
  <ItemGroup>
    <Content Include="Content\site.css" />
    <Content Include="Global.asax" />
    <Content Include="Web.config" />
    <Content Include="Web.Debug.config">
      <DependentUpon>Web.config</DependentUpon>
    </Content>
    <Content Include="Web.Release.config">
      <DependentUpon>Web.config</DependentUpon>
    </Content>
    <Content Include="Views\Web.config" />
    <Content Include="Views\_ViewStart.cshtml" />
    <Content Include="Views\Shared\_Layout.cshtml" />
    <Content Include="Views\Shared\Error.cshtml" />
    <Content Include="Views\Home\Index.cshtml" />
    <Content Include="packages.config" />
  </ItemGroup>
  <ItemGroup>
    <Folder Include="Models\" />
    <Folder Include="Scripts\" />
  </ItemGroup>
  <PropertyGroup>
    <VisualStudioVersion Condition="'$(VisualStudioVersion)' == ''">10.0</VisualStudioVersion>
    <VSToolsPath Condition="'$(VSToolsPath)' == ''">$(MSBuildExtensionsPath32)\Microsoft\VisualStudio\v$(VisualStudioVersion)</VSToolsPath>
  </PropertyGroup>
  <Import Project="$(MSBuildBinPath)\Microsoft.CSharp.targets" />
  <Import Project="$(VSToolsPath)\WebApplications\Microsoft.WebApplication.targets" Condition="'$(VSToolsPath)' != ''" />
  <ProjectExtensions>
    <VisualStudio>
      <FlavorProperties GUID="{349c5851-65df-11da-9384-00065b846f21}">
        <WebProjectProperties>
          <UseIIS>True</UseIIS>
          <AutoAssignPort>True</AutoAssignPort>
          <DevelopmentServerPort>__PORT__</DevelopmentServerPort>
          <DevelopmentServerVPath>/</DevelopmentServerVPath>
          <IISUrl>http://localhost:__PORT__/</IISUrl>
          <NTLMAuthentication>False</NTLMAuthentication>
          <UseCustomServer>False</UseCustomServer>
          <CustomServerUrl>
          </CustomServerUrl>
          <SaveServerSettingsInUserFile>False</SaveServerSettingsInUserFile>
        </WebProjectProperties>
      </FlavorProperties>
    </VisualStudio>
  </ProjectExtensions>
</Project>
'@

# ===========================================================================
#  Web.config del modulo
# ===========================================================================
Write-TemplateFile "__NAME__\Web.config" @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <configSections>
    <section name="entityFramework" type="System.Data.Entity.Internal.ConfigFile.EntityFrameworkSection, EntityFramework, Version=6.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" requirePermission="false" />
  </configSections>
  <appSettings>
    <add key="webpages:Version" value="3.0.0.0" />
    <add key="webpages:Enabled" value="false" />
    <add key="ClientValidationEnabled" value="true" />
    <add key="UnobtrusiveJavaScriptEnabled" value="true" />
    <!-- true = se omite el login y se entra como usuario de desarrollo -->
    <add key="ModoDesarrollo" value="true" />
  </appSettings>
  <connectionStrings>
    <add name="DefaultConnection"
         connectionString="data source=__SERVER__;initial catalog=__DB__;integrated security=True;multipleactiveresultsets=True;trustservercertificate=True;application name=__NAME__"
         providerName="System.Data.SqlClient" />
  </connectionStrings>
  <system.web>
    <compilation debug="true" targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" />
  </system.web>
  <entityFramework>
    <providers>
      <provider invariantName="System.Data.SqlClient" type="System.Data.Entity.SqlServer.SqlProviderServices, EntityFramework.SqlServer" />
    </providers>
  </entityFramework>
  <system.webServer>
    <validation validateIntegratedModeConfiguration="false" />
    <handlers>
      <remove name="ExtensionlessUrlHandler-Integrated-4.0" />
      <remove name="OPTIONSVerbHandler" />
      <remove name="TRACEVerbHandler" />
      <add name="ExtensionlessUrlHandler-Integrated-4.0" path="*." verb="*" type="System.Web.Handlers.TransferRequestHandler" preCondition="integratedMode,runtimeVersionv4.0" />
    </handlers>
  </system.webServer>
  <runtime>
    <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
      <dependentAssembly>
        <assemblyIdentity name="Microsoft.Web.Infrastructure" publicKeyToken="31bf3856ad364e35" />
        <bindingRedirect oldVersion="0.0.0.0-2.0.0.0" newVersion="2.0.0.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="Newtonsoft.Json" publicKeyToken="30ad4fe6b2a6aeed" />
        <bindingRedirect oldVersion="0.0.0.0-13.0.0.0" newVersion="13.0.0.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Web.Mvc" publicKeyToken="31bf3856ad364e35" />
        <bindingRedirect oldVersion="1.0.0.0-5.2.9.0" newVersion="5.2.9.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="System.Web.Optimization" publicKeyToken="31bf3856ad364e35" />
        <bindingRedirect oldVersion="1.0.0.0-1.1.0.0" newVersion="1.1.0.0" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="WebGrease" publicKeyToken="31bf3856ad364e35" />
        <bindingRedirect oldVersion="0.0.0.0-1.6.5135.21930" newVersion="1.6.5135.21930" />
      </dependentAssembly>
      <dependentAssembly>
        <assemblyIdentity name="Antlr3.Runtime" publicKeyToken="eb42632606e9261f" />
        <bindingRedirect oldVersion="0.0.0.0-3.5.0.2" newVersion="3.5.0.2" />
      </dependentAssembly>
    </assemblyBinding>
  </runtime>
</configuration>
'@

Write-TemplateFile "__NAME__\Web.Debug.config" @'
<?xml version="1.0" encoding="utf-8"?>
<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
</configuration>
'@

Write-TemplateFile "__NAME__\Web.Release.config" @'
<?xml version="1.0" encoding="utf-8"?>
<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
  <system.web>
    <compilation xdt:Transform="RemoveAttributes(debug)" />
  </system.web>
</configuration>
'@

# ===========================================================================
#  Global.asax
# ===========================================================================
Write-TemplateFile "__NAME__\Global.asax" @'
<%@ Application Codebehind="Global.asax.cs" Inherits="__NAME__.MvcApplication" Language="C#" %>
'@

Write-TemplateFile "__NAME__\Global.asax.cs" @'
using System.Web.Mvc;
using System.Web.Optimization;
using System.Web.Routing;

namespace __NAME__
{
    public class MvcApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            BundleConfig.RegisterBundles(BundleTable.Bundles);
        }
    }
}
'@

# ===========================================================================
#  App_Start
# ===========================================================================
Write-TemplateFile "__NAME__\App_Start\RouteConfig.cs" @'
using System.Web.Mvc;
using System.Web.Routing;

namespace __NAME__
{
    public class RouteConfig
    {
        public static void RegisterRoutes(RouteCollection routes)
        {
            routes.IgnoreRoute("{resource}.axd/{*pathInfo}");

            routes.MapRoute(
                name: "Default",
                url: "{controller}/{action}/{id}",
                defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional }
            );
        }
    }
}
'@

Write-TemplateFile "__NAME__\App_Start\FilterConfig.cs" @'
using System.Web.Mvc;

namespace __NAME__
{
    public class FilterConfig
    {
        public static void RegisterGlobalFilters(GlobalFilterCollection filters)
        {
            filters.Add(new HandleErrorAttribute());
        }
    }
}
'@

Write-TemplateFile "__NAME__\App_Start\BundleConfig.cs" @'
using System.Web.Optimization;

namespace __NAME__
{
    public class BundleConfig
    {
        public static void RegisterBundles(BundleCollection bundles)
        {
            bundles.Add(new StyleBundle("~/Content/css").Include("~/Content/site.css"));
        }
    }
}
'@

# ===========================================================================
#  Controllers  -> HomeController HEREDA del BaseController del PRINCIPAL
# ===========================================================================
Write-TemplateFile "__NAME__\Controllers\HomeController.cs" @'
using System.Web.Mvc;
using __MAINNS__.Controllers;   // BaseController de la app principal (__MAIN__)

namespace __NAME__.Controllers
{
    // Reutiliza la logica de sesion/ModoDesarrollo del proyecto principal.
    public class HomeController : BaseController
    {
        public ActionResult Index()
        {
            if (ValidaSesion())
            {
                return View();
            }
            return Salir();
        }
    }
}
'@

# ===========================================================================
#  Properties / AssemblyInfo
# ===========================================================================
Write-TemplateFile "__NAME__\Properties\AssemblyInfo.cs" @'
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("__NAME__")]
[assembly: AssemblyProduct("__NAME__")]
[assembly: AssemblyCopyright("Copyright ©  2026")]
[assembly: ComVisible(false)]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]
'@

# ===========================================================================
#  Views
# ===========================================================================
Write-TemplateFile "__NAME__\Views\_ViewStart.cshtml" @'
@{
    Layout = "~/Views/Shared/_Layout.cshtml";
}
'@

Write-TemplateFile "__NAME__\Views\Web.config" @'
<?xml version="1.0"?>
<configuration>
  <configSections>
    <sectionGroup name="system.web.webPages.razor" type="System.Web.WebPages.Razor.Configuration.RazorWebSectionGroup, System.Web.WebPages.Razor, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35">
      <section name="host" type="System.Web.WebPages.Razor.Configuration.HostSection, System.Web.WebPages.Razor, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" requirePermission="false" />
      <section name="pages" type="System.Web.WebPages.Razor.Configuration.RazorPagesSection, System.Web.WebPages.Razor, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" requirePermission="false" />
    </sectionGroup>
  </configSections>
  <system.web.webPages.razor>
    <host factoryType="System.Web.Mvc.MvcWebRazorHostFactory, System.Web.Mvc, Version=5.2.9.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" />
    <pages pageBaseType="System.Web.Mvc.WebViewPage">
      <namespaces>
        <add namespace="System.Web.Mvc" />
        <add namespace="System.Web.Mvc.Ajax" />
        <add namespace="System.Web.Mvc.Html" />
        <add namespace="System.Web.Optimization" />
        <add namespace="System.Web.Routing" />
        <add namespace="__NAME__" />
        <add namespace="__MAINNS__" />
      </namespaces>
    </pages>
  </system.web.webPages.razor>
  <appSettings>
    <add key="webpages:Enabled" value="false" />
  </appSettings>
  <system.web>
    <httpHandlers>
      <add path="*" verb="*" type="System.Web.HttpNotFoundHandler" />
    </httpHandlers>
    <pages
        validateRequest="false"
        pageParserFilterType="System.Web.Mvc.ViewTypeParserFilter, System.Web.Mvc, Version=5.2.9.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"
        pageBaseType="System.Web.Mvc.ViewPage, System.Web.Mvc, Version=5.2.9.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"
        userControlBaseType="System.Web.Mvc.ViewUserControl, System.Web.Mvc, Version=5.2.9.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35">
      <controls>
        <add assembly="System.Web.Mvc, Version=5.2.9.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" namespace="System.Web.Mvc" tagPrefix="mvc" />
      </controls>
    </pages>
  </system.web>
  <system.webServer>
    <handlers>
      <remove name="BlockViewHandler" />
      <add name="BlockViewHandler" path="*" verb="*" preCondition="integratedMode" type="System.Web.HttpNotFoundHandler" />
    </handlers>
  </system.webServer>
</configuration>
'@

Write-TemplateFile "__NAME__\Views\Shared\_Layout.cshtml" @'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewBag.Title - __NAME__</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" />
    @Styles.Render("~/Content/css")
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
        <div class="container">
            <a class="navbar-brand" href="@Url.Action("Index", "Home")">__NAME__ <small class="text-white-50">(modulo de __MAIN__)</small></a>
        </div>
    </nav>

    <div class="container mt-4">
        @RenderBody()
    </div>

    <footer class="container text-center text-muted mt-5 mb-3">
        <hr />
        <p>&copy; @DateTime.Now.Year - __NAME__</p>
    </footer>

    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    @RenderSection("scripts", required: false)
</body>
</html>
'@

Write-TemplateFile "__NAME__\Views\Shared\Error.cshtml" @'
@{
    ViewBag.Title = "Error";
}
<div class="alert alert-danger">
    <h2>Ocurrio un error procesando tu solicitud.</h2>
</div>
'@

Write-TemplateFile "__NAME__\Views\Home\Index.cshtml" @'
@{
    ViewBag.Title = "Inicio";
}
<div class="p-5 mb-4 bg-light rounded-3">
    <h1 class="display-5">Modulo __NAME__</h1>
    <p class="lead">Este es un modulo independiente enlazado al proyecto principal <strong>__MAIN__</strong>.</p>
    <p>Hereda <code>BaseController</code> de <code>__MAINNS__.Controllers</code> (sesion / ModoDesarrollo).</p>
    <p>Usuario actual: <strong>@ViewBag.UsuarioActual</strong></p>
    <hr />
    <p class="mb-0">Edita <code>Controllers/HomeController.cs</code> y <code>Views/Home/Index.cshtml</code> para empezar.</p>
</div>
'@

# ===========================================================================
#  Content / site.css
# ===========================================================================
Write-TemplateFile "__NAME__\Content\site.css" @'
body { padding-top: 0; }
'@

# ===========================================================================
#  Registrar el modulo en el .sln
# ===========================================================================
$typeGuid  = '{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}'
$lines     = Get-Content -LiteralPath $slnFile
$result    = New-Object System.Collections.Generic.List[string]
$inProjCfg = $false
$added     = $false
$cfgAdded  = $false

foreach ($line in $lines) {
    $trim = $line.Trim()

    if (-not $added -and $trim -eq 'Global') {
        $result.Add("Project(`"$typeGuid`") = `"$Name`", `"$Name\$Name.csproj`", `"{$modGuid}`"")
        $result.Add('EndProject')
        $added = $true
        $result.Add($line)
        continue
    }

    if ($trim -eq 'GlobalSection(ProjectConfigurationPlatforms) = postSolution') {
        $inProjCfg = $true
        $result.Add($line)
        continue
    }

    if ($inProjCfg -and $trim -eq 'EndGlobalSection') {
        $result.Add("`t`t{$modGuid}.Debug|Any CPU.ActiveCfg = Debug|Any CPU")
        $result.Add("`t`t{$modGuid}.Debug|Any CPU.Build.0 = Debug|Any CPU")
        $result.Add("`t`t{$modGuid}.Release|Any CPU.ActiveCfg = Release|Any CPU")
        $result.Add("`t`t{$modGuid}.Release|Any CPU.Build.0 = Release|Any CPU")
        $inProjCfg = $false
        $cfgAdded  = $true
        $result.Add($line)
        continue
    }

    $result.Add($line)
}

if (-not $added -or -not $cfgAdded) {
    throw "No se pudo actualizar el .sln automaticamente (formato inesperado). Agrega el proyecto manualmente en Visual Studio: clic derecho en la solucion -> Add -> Existing Project."
}

[System.IO.File]::WriteAllLines($slnFile, $result, (New-Object System.Text.UTF8Encoding $false))
Write-Host "  ~ $([System.IO.Path]::GetFileName($slnFile)) (modulo registrado)" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Listo. Modulo '$Name' agregado a la solucion." -ForegroundColor Green
Write-Host ""
Write-Host "Siguientes pasos:" -ForegroundColor Yellow
Write-Host "  1. En Visual Studio recarga la solucion (o cierra y abre $([System.IO.Path]::GetFileName($slnFile)))."
Write-Host "  2. Restaura NuGet si lo pide (comparte la carpeta 'packages' con el principal)."
Write-Host "  3. Compila la solucion."
Write-Host "  4. Para correr el modulo: clic derecho en '$Name' -> Set as Startup Project -> F5 (https://localhost:$Port)."
Write-Host ""
Write-Host "Enlace: $Name referencia a $mainName y su HomeController hereda de $mainNs.Controllers.BaseController." -ForegroundColor DarkGray
Write-Host "Config: SQL Server = $SqlServer | Base de datos = $Database | ModoDesarrollo = true" -ForegroundColor DarkGray
