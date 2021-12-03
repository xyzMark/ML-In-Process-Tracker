Attribute VB_Name = "DBconnections"
Dim E10DatabaseConnection As ADODB.Connection
Dim KioskDatabaseConnection As ADODB.Connection
Dim ML7DataBaseConnection As ADODB.Connection
Public ResultRecordSet As ADODB.Recordset
Dim sqlCommand As ADODB.Command
Dim fso As FileSystemObject
Public Enum Connections
    E10 = 0
    Kiosk = 1
    ML = 2
End Enum

'****************************************************
'*************  Connection/Query   ******************
'****************************************************

Private Sub Workbook_BeforeClose(Cancel As Boolean)
    'Close connection before closing workbook
    On Error Resume Next
    JobRecordSet.Close
    E10DatabaseConnection.Close
End Sub


Private Sub InitConnection()
    'Initialize E10 Connection on startup
    If ML7DataBaseConnection Is Nothing Then
        
        Set ML7DataBaseConnection = New ADODB.Connection
        ML7DataBaseConnection.ConnectionString = config.ML7_CONN_STRING
        ML7DataBaseConnection.Open
        
    End If
    
    
    If E10DatabaseConnection Is Nothing Then
    
        Set E10DatabaseConnection = New ADODB.Connection
        E10DatabaseConnection.ConnectionString = config.E10_CONN_STRING
        E10DatabaseConnection.Open
        
    End If
    If KioskDatabaseConnection Is Nothing Then
    
        Set KioskDatabaseConnection = New ADODB.Connection
        KioskDatabaseConnection.ConnectionString = config.KIOSK_CONN_STRING
        KioskDatabaseConnection.Open
        
    End If

End Sub

Private Function GetConnection(conn_enum As Connections) As ADODB.Connection
    Select Case conn_enum
        Case 0
            Set GetConnection = E10DatabaseConnection
        Case 1
            Set GetConnection = KioskDatabaseConnection
        Case 2
            Set GetConnection = ML7DataBaseConnection
        Case Else
    End Select
End Function


Public Function SQLQuery(queryString As String, conn_enum As Connections, params() As Variant)
    Call InitConnection
    Set ResultRecordSet = New ADODB.Recordset
    Set sqlCommand = New ADODB.Command
    With sqlCommand
        .ActiveConnection = GetConnection(conn_enum)
        .CommandType = adCmdText
        .CommandText = queryString
        
        On Error GoTo QueryFailed
        
        'Params structure
        'params(0) = "jh.JoNum,'NV1452'"
        If (Not params) = -1 Then GoTo 10  'If we have an empty array of parameters
        
        For i = 0 To UBound(params)
            Dim queryParam As ADODB.Parameter
            Set queryParam = .CreateParameter(Name:=Split(params(i), ",")(0), Type:=adVarChar, Size:=255, Direction:=adParamInput, Value:=Split(params(i), ",")(1))
            .Parameters.Append queryParam
        Next i
    End With
    
10
        'TODO Error check here potentially for EOF
    sqlCommand.CommandText = queryString
    
    ResultRecordSet.Open sqlCommand
    
    On Error GoTo 0
    If ResultRecordSet.EOF Then GoTo NoRows
    
    Exit Function
    
QueryFailed:
    Err.Raise Number:=vbObjectError + 3000, Description:="Func: SQLQuery() Failed" & vbCrLf & Join(params, vbCrLf) & vbCrLf & Err.Description
    
NoRows:
    Err.Raise Number:=vbObjectError + 2000, Description:="Func SQLQuery(): No Rows Returned"
End Function


'****************************************************
'*************  Public Functions   ******************
'****************************************************

Public Function GetShopLoadInfo() As Variant()
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    query = fso.OpenTextFile(config.QUERY_PATH & "JobLoad.sql", ForReading).ReadAll()
    
    'TODO:set the onError
    Call SQLQuery(queryString:=query, conn_enum:=Connections.E10, params:=params)
    
    'TODO: something here to check EOF
    GetShopLoadInfo = ResultRecordSet.GetRows()

End Function

Public Function GetEpicorCustName(projID As String) As String
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant

    query = fso.OpenTextFile(config.QUERY_PATH & "EpicorCustomer.sql", ForReading).ReadAll()
    params = Array("pr.ProjectID," & projID)
    
    Call SQLQuery(queryString:=query, conn_enum:=Connections.E10, params:=params)
    
    If Not ResultRecordSet.EOF Then
        GetEpicorCustName = ResultRecordSet.Fields(0)
    End If
End Function

Public Function GetKioskCustName(cusName As String) As String
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant

    query = fso.OpenTextFile(config.QUERY_PATH & "KioskCustomer.sql", ForReading).ReadAll()
    params = Array("ct.Abbreviation," & cusName)
    
    Call SQLQuery(queryString:=query, conn_enum:=Connections.Kiosk, params:=params)
    
    If Not ResultRecordSet.EOF Then
        GetKioskCustName = ResultRecordSet.Fields(0)
    End If
End Function



Public Function GetProductionInfo(jobNum As String, opNum As String) As Variant()
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    On Error GoTo prodInfoErr
    
    query = Split(fso.OpenTextFile(config.QUERY_PATH & "ProductionInfo.sql", ForReading).ReadAll(), ";")(0)
    params = Array("ld.JobNum," & jobNum, "ld.OprSeq," & opNum)
    
    'TODO:set the onError
    Call SQLQuery(queryString:=query, conn_enum:=Connections.E10, params:=params)
    
    If ResultRecordSet.EOF Then Exit Function
    GetProductionInfo = ResultRecordSet.GetRows()
    
    Exit Function
    
prodInfoErr:
    If Err.Number = vbObjectError + 2000 Then  'No results returned
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: E10-Get1XSHIFTInsps" & vbCrLf & Err.Description
    End If

End Function

Public Function GetProductionInfoSUM(jobNum As String, opNum As String) As Variant()
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    query = Split(fso.OpenTextFile(config.QUERY_PATH & "ProductionInfo.sql", ForReading).ReadAll(), ";")(1)
    params = Array("ld.JobNum," & jobNum, "ld.OprSeq," & opNum)
    
    
    'TODO:set the onError
    Call SQLQuery(queryString:=query, conn_enum:=Connections.E10, params:=params)
    
    'TODO: something here to check EOF
    GetProductionInfoSUM = ResultRecordSet.GetRows()

End Function


Function Get1XSHIFTInsps(JobID As String, Operation As Variant) As String
    
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    On Error GoTo shiftErr
    query = fso.OpenTextFile(config.QUERY_PATH & "1XSHIFT.sql").ReadAll
    params = Array("jo.JobNum," & JobID, "jo.OprSeq," & Operation)
    
    Call SQLQuery(queryString:=query, conn_enum:=Connections.E10, params:=params)
    
    Get1XSHIFTInsps = ResultRecordSet.Fields(1).Value
    Exit Function
    
shiftErr:
    If Err.Number = vbObjectError + 2000 Then
        Get1XSHIFTInsps = "0"  'Technically, if we didnt run any shifts, we dont owe any inspections
        Exit Function
    Else
        Err.Raise Number:=Err.Number, Description:="Func: E10-Get1XSHIFTInsps" & vbCrLf & Err.Description
    End If
    
End Function

Public Function GetEmployeeListSum(jobNum As String, faRoutine As String) As Variant()
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    query = Split(fso.OpenTextFile(config.QUERY_PATH & "MLMeasurementInfo.sql", ForReading).ReadAll(), ";")(0)
    params = Array("r.RunName," & jobNum, "rt.RoutineName," & faRoutine, "r.RunName," & jobNum, "rt.RoutineName," & faRoutine)
    
    On Error GoTo QueryError
    'TODO:set the onError
    Call SQLQuery(queryString:=query, conn_enum:=Connections.ML, params:=params)
    
    'TODO: something here to check EOF
    GetEmployeeListSum = ResultRecordSet.GetRows()
    
noResults:

    Exit Function
    
QueryError:
    If Err.Number = vbObjectError + 2000 Then
        Resume noResults
    Else
        MsgBox "Func: GetEmployeeListSum() Failed" & vbCrLf & jobNume & vbCrLf & faRoutine & vbCrLf & vbCrLf & Err.Description
    End If

End Function

Public Function GetJobUnqiueRoutines(partnum As String, rev As String, faRoutine As String) As Variant()
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    query = fso.OpenTextFile(config.QUERY_PATH & "MLUniqueRoutineList.sql", ForReading).ReadAll()
'    query = Replace(query, "{FA_TYPE}", faRoutine)
    params = Array("p.PartName," & partnum & "_" & rev, "rt.RoutineName," & faRoutine)
    
    On Error GoTo QueryError
    'TODO:set the onError
    Call SQLQuery(queryString:=query, conn_enum:=Connections.ML, params:=params)
    
    'TODO: something here to check EOF
    GetJobUnqiueRoutines = ResultRecordSet.GetRows()
    
noResults:

    Exit Function
    
QueryError:
    If Err.Number = vbObjectError + 2000 Then
        Resume noResults
    Else
        MsgBox "Func: GetJobUnqiueRoutines() Failed" & vbCrLf & partnum & "_" & rev & vbCrLf & faRoutine & vbCrLf & vbCrLf & Err.Description
    End If

End Function

Public Function GetEmployeeInspCount(jobNum As String, faRoutine As String, employees As Variant) As Variant()
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    query = Split(fso.OpenTextFile(config.QUERY_PATH & "MLMeasurementInfo.sql", ForReading).ReadAll(), ";")(1)
    query = Replace(query, "{Employees}", employees)
    params = Array("r.RunName," & jobNum, "rt.RoutineName," & faRoutine, "r.RunName," & jobNum, "rt.RoutineName," & faRoutine)
    
    On Error GoTo QueryError
    'If we got this far, then there should be some results
    Call SQLQuery(queryString:=query, conn_enum:=Connections.ML, params:=params)
    
    GetEmployeeInspCount = ResultRecordSet.GetRows()

    Exit Function
    
QueryError:
    MsgBox "Func: GetEmployeeInspCount() Failed" & vbCrLf & jobNume & vbCrLf & faRoutine & vbCrLf & vbCrLf & Err.Description
    
End Function


Private Function PartMLReady(partnum As String, revNum As String) As Variant
    Set fso = New FileSystemObject
    Dim query As String
    Dim params() As Variant
    
    query = fso.OpenTextFile(config.QUERY_PATH & "PartMLReady.sql", ForReading).ReadAll()
    params = Array("pr.PartNum," & partnum, "pr.RevisionNum," & revNum)

    Call SQLQuery(queryString:=query, conn_enum:=Connections.E10, params:=params)
    
    PartMLReady = ResultRecordSet.GetRows()

End Function



'****************************************************
'*************  Helper Functions   ******************
'****************************************************



Function IsMeasurLinkJob(jobNumber As String, partNumber As String, PartRev As String, MachineType As String) As Boolean
    If MachineType = "" Then GoTo 10

    Dim ReadyIndexCol As Collection
    Set ReadyIndexCol = New Collection
    Dim machines() As Variant
    
    'On Error GoTo 10
    
    machines = PartMLReady(partnum:=partNumber, revNum:=PartRev)
    
    If (Not machines) = -1 Then GoTo 10   'No information for this part, but we may still have created an excel IR for it.
    
    Dim index As Integer
    Dim i As Integer
    
    For i = 0 To UBound(machines)
        If machines(i, 0) = True Then
            If index = 0 Then
                ReadyIndexCol.Add ("")
            Else
                ReadyIndexCol.Add (CStr(index + 1))
            End If
            
        End If
        index = index + 1
    Next i
    
    If ReadyIndexCol.Count = 0 Then GoTo 10
    
    Dim MachineRecordSet As ADODB.Recordset
    Dim MachineQuerySelect As String
    MachineQuerySelect = "SELECT "
    Dim MachineQueryJoins As String
    Dim MachineQueryCriteria As String
    MachineQueryCriteria = " WHERE pr.PartNum = ? AND pr.RevisionNum = ?"
    
    
    For ReadyIndex = 1 To ReadyIndexCol.Count
        MachineQuerySelect = MachineQuerySelect & "ud" & ReadyIndexCol(ReadyIndex) & ".CodeDesc,"
        MachineQueryJoins = MachineQueryJoins & " LEFT OUTER JOIN EpicorLive10.dbo.UDCodes ud" & ReadyIndexCol(ReadyIndex) & " ON pr.ProgramRsrc" & ReadyIndexCol(ReadyIndex) & "_c = ud" & ReadyIndexCol(ReadyIndex) & ".CodeID"
        MachineQueryCriteria = MachineQueryCriteria & " AND ud" & ReadyIndexCol(ReadyIndex) & ".CodeTypeID = 'PGRMRSRC'"
    Next ReadyIndex
    
    MachineQuerySelect = Left(MachineQuerySelect, Len(MachineQuerySelect) - 1) & " "
    
    MachineQueryFooter = " FROM EpicorLive10.dbo.PartRev pr " _
    
    Dim machineQuery As String
    machineQuery = MachineQuerySelect & MachineQueryFooter & MachineQueryJoins & MachineQueryCriteria
    Dim params() As Variant
    params = Array("pr.PartNum," & partNumber, "pr.RevisionNum," & PartRev)
    
    SQLQuery queryString:=machineQuery, conn_enum:=Connections.E10, params:=params
    Set MachineRecordSet = ResultRecordSet
    
    For Each Machine In MachineRecordSet.Fields
        If Machine.Value = MachineType Then
            IsMeasurLinkJob = True
        End If
    Next Machine
                        
10

End Function


















