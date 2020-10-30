// Code generated by protoc-gen-go-grpc. DO NOT EDIT.

package rpc

import (
	context "context"
	empty "github.com/golang/protobuf/ptypes/empty"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
)

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
const _ = grpc.SupportPackageIsVersion7

// TestpmdClient is the client API for Testpmd service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type TestpmdClient interface {
	GetMacAddress(ctx context.Context, in *Pci, opts ...grpc.CallOption) (*MacAddress, error)
	GetPortInfo(ctx context.Context, in *Pci, opts ...grpc.CallOption) (*PortInfo, error)
	ListPorts(ctx context.Context, in *empty.Empty, opts ...grpc.CallOption) (*PortList, error)
	IcmpMode(ctx context.Context, in *empty.Empty, opts ...grpc.CallOption) (*Success, error)
	IoMode(ctx context.Context, in *empty.Empty, opts ...grpc.CallOption) (*Success, error)
	MacMode(ctx context.Context, in *PeerMacs, opts ...grpc.CallOption) (*Success, error)
}

type testpmdClient struct {
	cc grpc.ClientConnInterface
}

func NewTestpmdClient(cc grpc.ClientConnInterface) TestpmdClient {
	return &testpmdClient{cc}
}

func (c *testpmdClient) GetMacAddress(ctx context.Context, in *Pci, opts ...grpc.CallOption) (*MacAddress, error) {
	out := new(MacAddress)
	err := c.cc.Invoke(ctx, "/testpmd.testpmd/GetMacAddress", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *testpmdClient) GetPortInfo(ctx context.Context, in *Pci, opts ...grpc.CallOption) (*PortInfo, error) {
	out := new(PortInfo)
	err := c.cc.Invoke(ctx, "/testpmd.testpmd/GetPortInfo", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *testpmdClient) ListPorts(ctx context.Context, in *empty.Empty, opts ...grpc.CallOption) (*PortList, error) {
	out := new(PortList)
	err := c.cc.Invoke(ctx, "/testpmd.testpmd/ListPorts", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *testpmdClient) IcmpMode(ctx context.Context, in *empty.Empty, opts ...grpc.CallOption) (*Success, error) {
	out := new(Success)
	err := c.cc.Invoke(ctx, "/testpmd.testpmd/IcmpMode", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *testpmdClient) IoMode(ctx context.Context, in *empty.Empty, opts ...grpc.CallOption) (*Success, error) {
	out := new(Success)
	err := c.cc.Invoke(ctx, "/testpmd.testpmd/IoMode", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *testpmdClient) MacMode(ctx context.Context, in *PeerMacs, opts ...grpc.CallOption) (*Success, error) {
	out := new(Success)
	err := c.cc.Invoke(ctx, "/testpmd.testpmd/MacMode", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// TestpmdServer is the server API for Testpmd service.
// All implementations must embed UnimplementedTestpmdServer
// for forward compatibility
type TestpmdServer interface {
	GetMacAddress(context.Context, *Pci) (*MacAddress, error)
	GetPortInfo(context.Context, *Pci) (*PortInfo, error)
	ListPorts(context.Context, *empty.Empty) (*PortList, error)
	IcmpMode(context.Context, *empty.Empty) (*Success, error)
	IoMode(context.Context, *empty.Empty) (*Success, error)
	MacMode(context.Context, *PeerMacs) (*Success, error)
	mustEmbedUnimplementedTestpmdServer()
}

// UnimplementedTestpmdServer must be embedded to have forward compatible implementations.
type UnimplementedTestpmdServer struct {
}

func (UnimplementedTestpmdServer) GetMacAddress(context.Context, *Pci) (*MacAddress, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GetMacAddress not implemented")
}
func (UnimplementedTestpmdServer) GetPortInfo(context.Context, *Pci) (*PortInfo, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GetPortInfo not implemented")
}
func (UnimplementedTestpmdServer) ListPorts(context.Context, *empty.Empty) (*PortList, error) {
	return nil, status.Errorf(codes.Unimplemented, "method ListPorts not implemented")
}
func (UnimplementedTestpmdServer) IcmpMode(context.Context, *empty.Empty) (*Success, error) {
	return nil, status.Errorf(codes.Unimplemented, "method IcmpMode not implemented")
}
func (UnimplementedTestpmdServer) IoMode(context.Context, *empty.Empty) (*Success, error) {
	return nil, status.Errorf(codes.Unimplemented, "method IoMode not implemented")
}
func (UnimplementedTestpmdServer) MacMode(context.Context, *PeerMacs) (*Success, error) {
	return nil, status.Errorf(codes.Unimplemented, "method MacMode not implemented")
}
func (UnimplementedTestpmdServer) mustEmbedUnimplementedTestpmdServer() {}

// UnsafeTestpmdServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to TestpmdServer will
// result in compilation errors.
type UnsafeTestpmdServer interface {
	mustEmbedUnimplementedTestpmdServer()
}

func RegisterTestpmdServer(s grpc.ServiceRegistrar, srv TestpmdServer) {
	s.RegisterService(&_Testpmd_serviceDesc, srv)
}

func _Testpmd_GetMacAddress_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(Pci)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(TestpmdServer).GetMacAddress(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/testpmd.testpmd/GetMacAddress",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(TestpmdServer).GetMacAddress(ctx, req.(*Pci))
	}
	return interceptor(ctx, in, info, handler)
}

func _Testpmd_GetPortInfo_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(Pci)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(TestpmdServer).GetPortInfo(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/testpmd.testpmd/GetPortInfo",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(TestpmdServer).GetPortInfo(ctx, req.(*Pci))
	}
	return interceptor(ctx, in, info, handler)
}

func _Testpmd_ListPorts_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(empty.Empty)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(TestpmdServer).ListPorts(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/testpmd.testpmd/ListPorts",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(TestpmdServer).ListPorts(ctx, req.(*empty.Empty))
	}
	return interceptor(ctx, in, info, handler)
}

func _Testpmd_IcmpMode_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(empty.Empty)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(TestpmdServer).IcmpMode(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/testpmd.testpmd/IcmpMode",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(TestpmdServer).IcmpMode(ctx, req.(*empty.Empty))
	}
	return interceptor(ctx, in, info, handler)
}

func _Testpmd_IoMode_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(empty.Empty)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(TestpmdServer).IoMode(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/testpmd.testpmd/IoMode",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(TestpmdServer).IoMode(ctx, req.(*empty.Empty))
	}
	return interceptor(ctx, in, info, handler)
}

func _Testpmd_MacMode_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(PeerMacs)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(TestpmdServer).MacMode(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/testpmd.testpmd/MacMode",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(TestpmdServer).MacMode(ctx, req.(*PeerMacs))
	}
	return interceptor(ctx, in, info, handler)
}

var _Testpmd_serviceDesc = grpc.ServiceDesc{
	ServiceName: "testpmd.testpmd",
	HandlerType: (*TestpmdServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "GetMacAddress",
			Handler:    _Testpmd_GetMacAddress_Handler,
		},
		{
			MethodName: "GetPortInfo",
			Handler:    _Testpmd_GetPortInfo_Handler,
		},
		{
			MethodName: "ListPorts",
			Handler:    _Testpmd_ListPorts_Handler,
		},
		{
			MethodName: "IcmpMode",
			Handler:    _Testpmd_IcmpMode_Handler,
		},
		{
			MethodName: "IoMode",
			Handler:    _Testpmd_IoMode_Handler,
		},
		{
			MethodName: "MacMode",
			Handler:    _Testpmd_MacMode_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "rpc.proto",
}